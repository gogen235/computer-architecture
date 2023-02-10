`define MEM_SIZE (1 << 18)
`define CACHE_SIZE (1 << 11)
`define CACHE_LINE_SIZE (1 << 4)
`define CACHE_LINE_COUNT (1 << 7)
`define CACHE_WAY 2
`define CACHE_SETS_COUNT (1 << 6)
`define CACHE_TAG_SIZE 8
`define CACHE_SET_SIZE 6
`define CACHE_OFFSET_SIZE 4
`define CACHE_ADDR_SIZE 18
`define ADDR1_BUS_SIZE 14
`define ADDR2_BUS_SIZE 14
`define DATA1_BUS_SIZE 16
`define DATA2_BUS_SIZE 16
`define CTR1_BUS_SIZE 3
`define CTR2_BUS_SIZE 2

module MemCTR(
    inout wire[`DATA2_BUS_SIZE - 1 : 0] D2, 
    inout wire[`CTR2_BUS_SIZE - 1 : 0] C2,
    input reg[`ADDR2_BUS_SIZE - 1 : 0] A2,  
    input reg RESET, 
    input reg M_DUMP,
    input reg CLK
    );

    reg[`DATA2_BUS_SIZE - 1 : 0] D2_1 = 'hz;
    reg[`CTR2_BUS_SIZE - 1 : 0] C2_1 = 'hz;

    assign D2 = D2_1;
    assign C2 = C2_1;

    reg[7:0]  mem[`MEM_SIZE - 1 : 0];
    integer SEED = 225526;
    int fd;
    reg[`CACHE_ADDR_SIZE - 1 : 0] addr;

    initial reset();

    always @(posedge CLK && RESET == 1) begin  
        reset();
    end

    always @(posedge CLK && M_DUMP == 1) begin
        fd = $fopen ("DUMP_M.ext", "w");
        for (int e = 0; e < `MEM_SIZE; e++)
            $fdisplay (fd, "#%d# %b", e, mem[e]);
        $fclose(fd);
    end

    always @(posedge CLK) begin
        if (C2 === 2) begin
            _READ_LINE();
        end else if (C2 === 3) begin
            _WRITE_LINE();
        end
    end
    
    task automatic _wait(input int count);
        for (int m = 0; m < count; m++) @(posedge CLK);
    endtask

    task automatic reset();
        for (int h = 0; h < `MEM_SIZE; h += 1)
            mem[h] = $random(SEED)>>16;  
    endtask

    task automatic _READ_LINE();
        addr = A2 << `CACHE_OFFSET_SIZE;
        _wait(1);
        C2_1 = 0;
        _wait(99);
        C2_1 = 1;
        for (int w = 0; w < 8; w++) begin
            D2_1 = (mem[addr + w * 2 + 1] << 8) + (mem[addr + w * 2]);
            _wait(1);
        end
        C2_1 = 'hz;
        D2_1 = 'hz;
    endtask

    task automatic _WRITE_LINE();
        addr = A2 << `CACHE_OFFSET_SIZE;
        for (int d = 0; d < 8; d++) begin
            mem[addr + d * 2] = D2 % (1 << 8);
            mem[addr + d * 2 + 1] = D2 >> 8;
            _wait(1);
            C2_1 = 0;
        end
        _wait(92);
        C2_1 = 1;
        _wait(1);
        C2_1 = 'hz;
    endtask

endmodule