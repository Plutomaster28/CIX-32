// CIX-32 Mode Controller - Handles Real Mode, Protected Mode, and Virtual 8086 Mode
module cix32_mode_controller (
    input wire clk,
    input wire rst_n,
    
    // Control register interface
    input wire [31:0] cr0,
    input wire [31:0] cr3,
    input wire [31:0] cr4,
    
    // Current operating mode
    output reg [2:0] cpu_mode,      // 000=Real, 001=Protected, 010=Virtual8086, 011=Long
    output reg paging_enabled,
    output reg protection_enabled,
    output reg virtual_8086_mode,
    
    // Memory management
    input wire [31:0] linear_address,
    output reg [31:0] physical_address,
    output reg page_fault,
    
    // Privilege level
    input wire [1:0] current_privilege_level,
    output reg privilege_violation,
    
    // Segment descriptor cache
    input wire [63:0] segment_descriptor,
    output reg segment_valid,
    output reg [31:0] segment_base,
    output reg [31:0] segment_limit,
    output reg [3:0] segment_type,
    
    // Global/Local descriptor tables
    input wire [47:0] gdtr,         // Global Descriptor Table Register
    input wire [47:0] ldtr,         // Local Descriptor Table Register
    input wire [47:0] idtr,         // Interrupt Descriptor Table Register
    
    // Task State Segment
    input wire [15:0] task_register,
    output reg task_switch_required
);

    // CPU Mode definitions
    parameter REAL_MODE = 3'h0;
    parameter PROTECTED_MODE = 3'h1;
    parameter VIRTUAL_8086_MODE = 3'h2;
    parameter LONG_MODE = 3'h3;       // 64-bit mode (future extension)
    
    // CR0 bit definitions
    wire pe_bit = cr0[0];        // Protection Enable
    wire mp_bit = cr0[1];        // Monitor Coprocessor
    wire em_bit = cr0[2];        // Emulation
    wire ts_bit = cr0[3];        // Task Switched
    wire et_bit = cr0[4];        // Extension Type
    wire ne_bit = cr0[5];        // Numeric Error
    wire wp_bit = cr0[16];       // Write Protect
    wire am_bit = cr0[18];       // Alignment Mask
    wire nw_bit = cr0[29];       // Not Write-through
    wire cd_bit = cr0[30];       // Cache Disable
    wire pg_bit = cr0[31];       // Paging
    
    // EFLAGS VM bit (would come from flags register)
    reg vm_flag;
    
    // Page directory and table entries
    reg [31:0] page_directory_entry;
    reg [31:0] page_table_entry;
    
    // Translation Lookaside Buffer (TLB) - simplified
    reg [31:0] tlb_virtual [0:15];
    reg [31:0] tlb_physical [0:15];
    reg [15:0] tlb_valid;
    reg [3:0] tlb_index;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cpu_mode <= REAL_MODE;
            paging_enabled <= 1'b0;
            protection_enabled <= 1'b0;
            virtual_8086_mode <= 1'b0;
            page_fault <= 1'b0;
            privilege_violation <= 1'b0;
            segment_valid <= 1'b0;
            task_switch_required <= 1'b0;
            tlb_valid <= 16'h0;
            tlb_index <= 4'h0;
            vm_flag <= 1'b0; // Would be connected to EFLAGS[17]
        end else begin
            // Determine current CPU mode
            protection_enabled <= pe_bit;
            paging_enabled <= pg_bit;
            
            if (!pe_bit) begin
                // Real Mode
                cpu_mode <= REAL_MODE;
                virtual_8086_mode <= 1'b0;
                
                // Real mode address calculation: Segment:Offset
                physical_address <= linear_address; // Simplified
                segment_valid <= 1'b1;
                segment_base <= 32'h0;
                segment_limit <= 32'hFFFFF; // 1MB limit in real mode
                
            end else if (pe_bit && vm_flag) begin
                // Virtual 8086 Mode
                cpu_mode <= VIRTUAL_8086_MODE;
                virtual_8086_mode <= 1'b1;
                
                // Virtual 8086 mode uses real mode addressing with protection
                physical_address <= linear_address;
                segment_valid <= 1'b1;
                
            end else begin
                // Protected Mode
                cpu_mode <= PROTECTED_MODE;
                virtual_8086_mode <= 1'b0;
                
                // Parse segment descriptor
                segment_base <= segment_descriptor[31:16] | (segment_descriptor[63:56] << 24);
                segment_limit <= segment_descriptor[15:0] | (segment_descriptor[51:48] << 16);
                segment_type <= segment_descriptor[11:8];
                segment_valid <= segment_descriptor[47]; // Present bit
                
                // Check privilege level
                if (current_privilege_level > segment_descriptor[46:45]) begin
                    privilege_violation <= 1'b1;
                end else begin
                    privilege_violation <= 1'b0;
                end
                
                // Address translation
                if (paging_enabled) begin
                    // Paged virtual memory
                    // Check TLB first
                    if (tlb_valid[linear_address[15:12]] && 
                        tlb_virtual[linear_address[15:12]] == linear_address[31:12]) begin
                        // TLB hit
                        physical_address <= tlb_physical[linear_address[15:12]] | linear_address[11:0];
                    end else begin
                        // TLB miss - perform page table walk
                        // This is simplified - real implementation would access memory
                        
                        // Page Directory Entry (PDE)
                        page_directory_entry <= 32'h00000001; // Simplified: present, writable
                        
                        // Page Table Entry (PTE) 
                        page_table_entry <= 32'h00000001; // Simplified: present, writable
                        
                        if (page_directory_entry[0] && page_table_entry[0]) begin
                            // Pages are present
                            physical_address <= {page_table_entry[31:12], linear_address[11:0]};
                            
                            // Update TLB
                            tlb_virtual[tlb_index] <= linear_address[31:12];
                            tlb_physical[tlb_index] <= page_table_entry[31:12];
                            tlb_valid[tlb_index] <= 1'b1;
                            tlb_index <= tlb_index + 1;
                            
                            page_fault <= 1'b0;
                        end else begin
                            // Page fault
                            page_fault <= 1'b1;
                            physical_address <= 32'h0;
                        end
                    end
                end else begin
                    // Flat memory model (no paging)
                    physical_address <= linear_address;
                end
            end
        end
    end

endmodule

// CIX-32 Cache Controller - L1 Instruction and Data Caches
module cix32_cache_controller (
    input wire clk,
    input wire rst_n,
    
    // CPU interface
    input wire [31:0] cpu_addr,
    input wire [31:0] cpu_wdata,
    output reg [31:0] cpu_rdata,
    input wire cpu_we,
    input wire cpu_re,
    input wire cpu_cacheable,
    output reg cpu_ready,
    output reg cache_hit,
    output reg cache_miss,
    
    // Memory interface  
    output reg [31:0] mem_addr,
    output reg [31:0] mem_wdata,
    input wire [31:0] mem_rdata,
    output reg mem_we,
    output reg mem_re,
    input wire mem_ready,
    
    // Cache control
    input wire cache_enable,
    input wire cache_flush,
    input wire [1:0] cache_policy,  // 00=write-through, 01=write-back, 10=write-around
    
    // Performance counters
    output reg [31:0] hit_count,
    output reg [31:0] miss_count,
    output reg [31:0] eviction_count
);

    // Cache parameters
    parameter CACHE_SIZE = 8192;      // 8KB cache
    parameter CACHE_LINE_SIZE = 32;   // 32 bytes per line
    parameter CACHE_WAYS = 2;         // 2-way set associative
    parameter CACHE_SETS = CACHE_SIZE / (CACHE_LINE_SIZE * CACHE_WAYS); // 128 sets
    
    // Cache arrays
    reg [31:0] cache_data [0:CACHE_WAYS-1][0:CACHE_SETS-1][0:7]; // 8 words per line
    reg [19:0] cache_tag [0:CACHE_WAYS-1][0:CACHE_SETS-1];       // Tag array
    reg cache_valid [0:CACHE_WAYS-1][0:CACHE_SETS-1];            // Valid bits
    reg cache_dirty [0:CACHE_WAYS-1][0:CACHE_SETS-1];            // Dirty bits
    reg [CACHE_WAYS-1:0] cache_lru [0:CACHE_SETS-1];             // LRU bits
    
    // Address breakdown
    wire [1:0] word_offset = cpu_addr[3:2];   // Word within cache line
    wire [2:0] line_offset = cpu_addr[4:2];   // Word offset (8 words per line)
    wire [6:0] cache_index = cpu_addr[11:5];  // Cache set index
    wire [19:0] cache_tag_addr = cpu_addr[31:12]; // Tag
    
    // Cache state machine
    reg [2:0] cache_state;
    parameter CACHE_IDLE = 3'h0, CACHE_LOOKUP = 3'h1, CACHE_ALLOCATE = 3'h2,
              CACHE_WRITEBACK = 3'h3, CACHE_FILL = 3'h4;
    
    // Cache way selection
    reg cache_way;
    reg cache_hit_way;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cpu_ready <= 1'b1;
            cache_hit <= 1'b0;
            cache_miss <= 1'b0;
            cache_state <= CACHE_IDLE;
            hit_count <= 32'h0;
            miss_count <= 32'h0;
            eviction_count <= 32'h0;
            mem_we <= 1'b0;
            mem_re <= 1'b0;
            
            // Initialize cache arrays
            for (integer way = 0; way < CACHE_WAYS; way = way + 1) begin
                for (integer set = 0; set < CACHE_SETS; set = set + 1) begin
                    cache_valid[way][set] <= 1'b0;
                    cache_dirty[way][set] <= 1'b0;
                    cache_tag[way][set] <= 20'h0;
                    for (integer word = 0; word < 8; word = word + 1) begin
                        cache_data[way][set][word] <= 32'h0;
                    end
                end
            end
            
            for (integer set = 0; set < CACHE_SETS; set = set + 1) begin
                cache_lru[set] <= 2'b00;
            end
            
        end else if (cache_enable) begin
            case (cache_state)
                CACHE_IDLE: begin
                    if ((cpu_re || cpu_we) && cpu_cacheable) begin
                        cpu_ready <= 1'b0;
                        cache_state <= CACHE_LOOKUP;
                    end else if (cpu_re || cpu_we) begin
                        // Non-cacheable access - bypass cache
                        mem_addr <= cpu_addr;
                        mem_wdata <= cpu_wdata;
                        mem_we <= cpu_we;
                        mem_re <= cpu_re;
                        cpu_rdata <= mem_rdata;
                        cpu_ready <= mem_ready;
                    end
                end
                
                CACHE_LOOKUP: begin
                    // Check for cache hit
                    cache_hit <= 1'b0;
                    cache_miss <= 1'b0;
                    
                    for (integer way = 0; way < CACHE_WAYS; way = way + 1) begin
                        if (cache_valid[way][cache_index] && 
                            cache_tag[way][cache_index] == cache_tag_addr) begin
                            // Cache hit
                            cache_hit <= 1'b1;
                            cache_hit_way <= way;
                            hit_count <= hit_count + 1;
                            
                            if (cpu_re) begin
                                // Read hit
                                cpu_rdata <= cache_data[way][cache_index][line_offset];
                                cpu_ready <= 1'b1;
                                cache_state <= CACHE_IDLE;
                            end else if (cpu_we) begin
                                // Write hit
                                cache_data[way][cache_index][line_offset] <= cpu_wdata;
                                
                                if (cache_policy == 2'b00) begin
                                    // Write-through
                                    mem_addr <= cpu_addr;
                                    mem_wdata <= cpu_wdata;
                                    mem_we <= 1'b1;
                                    cpu_ready <= mem_ready;
                                    cache_state <= CACHE_IDLE;
                                end else begin
                                    // Write-back
                                    cache_dirty[way][cache_index] <= 1'b1;
                                    cpu_ready <= 1'b1;
                                    cache_state <= CACHE_IDLE;
                                end
                            end
                            
                            // Update LRU
                            cache_lru[cache_index][way] <= 1'b1;
                            for (integer other_way = 0; other_way < CACHE_WAYS; other_way = other_way + 1) begin
                                if (other_way != way) begin
                                    cache_lru[cache_index][other_way] <= 1'b0;
                                end
                            end
                        end
                    end
                    
                    if (!cache_hit) begin
                        // Cache miss
                        cache_miss <= 1'b1;
                        miss_count <= miss_count + 1;
                        
                        // Select way for replacement (LRU)
                        cache_way <= (cache_lru[cache_index] == 2'b01) ? 1'b0 : 1'b1;
                        
                        // Check if we need to writeback
                        if (cache_valid[cache_way][cache_index] && 
                            cache_dirty[cache_way][cache_index]) begin
                            cache_state <= CACHE_WRITEBACK;
                        end else begin
                            cache_state <= CACHE_FILL;
                        end
                    end
                end
                
                CACHE_WRITEBACK: begin
                    // Writeback dirty line
                    mem_addr <= {cache_tag[cache_way][cache_index], cache_index, 5'b00000};
                    mem_wdata <= cache_data[cache_way][cache_index][0]; // Simplified
                    mem_we <= 1'b1;
                    
                    if (mem_ready) begin
                        eviction_count <= eviction_count + 1;
                        cache_dirty[cache_way][cache_index] <= 1'b0;
                        mem_we <= 1'b0;
                        cache_state <= CACHE_FILL;
                    end
                end
                
                CACHE_FILL: begin
                    // Fill cache line from memory
                    mem_addr <= {cache_tag_addr, cache_index, 5'b00000};
                    mem_re <= 1'b1;
                    
                    if (mem_ready) begin
                        // Fill entire cache line (simplified - would need burst)
                        for (integer word = 0; word < 8; word = word + 1) begin
                            cache_data[cache_way][cache_index][word] <= mem_rdata;
                        end
                        
                        cache_tag[cache_way][cache_index] <= cache_tag_addr;
                        cache_valid[cache_way][cache_index] <= 1'b1;
                        cache_dirty[cache_way][cache_index] <= 1'b0;
                        
                        mem_re <= 1'b0;
                        
                        // Complete the original request
                        if (cpu_re) begin
                            cpu_rdata <= cache_data[cache_way][cache_index][line_offset];
                        end else if (cpu_we) begin
                            cache_data[cache_way][cache_index][line_offset] <= cpu_wdata;
                            if (cache_policy != 2'b01) begin
                                cache_dirty[cache_way][cache_index] <= 1'b1;
                            end
                        end
                        
                        cpu_ready <= 1'b1;
                        cache_state <= CACHE_IDLE;
                    end
                end
                
                default: begin
                    cache_state <= CACHE_IDLE;
                end
            endcase
            
            // Handle cache flush
            if (cache_flush) begin
                for (integer way = 0; way < CACHE_WAYS; way = way + 1) begin
                    for (integer set = 0; set < CACHE_SETS; set = set + 1) begin
                        cache_valid[way][set] <= 1'b0;
                        cache_dirty[way][set] <= 1'b0;
                    end
                end
            end
        end
    end

endmodule
