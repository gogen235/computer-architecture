`define ADDR1_BUS_SIZE 14
`define ADDR2_BUS_SIZE 14
`define DATA1_BUS_SIZE 16
`define DATA2_BUS_SIZE 16
`define CTR1_BUS_SIZE 3
`define CTR2_BUS_SIZE 2

`include "CPU.sv"
`include "Cache.sv"
`include "MemCTR.sv"

module TestRam();
    reg CLK = 0;
    reg C_DUMP;
    reg M_DUMP;
    reg RESET = 0;
    reg[`ADDR1_BUS_SIZE - 1 : 0] A1;
    reg[`ADDR2_BUS_SIZE - 1 : 0] A2;
    wire[`DATA1_BUS_SIZE - 1 : 0] D1; 
    wire[`DATA2_BUS_SIZE - 1 : 0] D2; 
    wire[`CTR1_BUS_SIZE - 1 : 0] C1;
    wire[`CTR2_BUS_SIZE - 1 : 0] C2;

    CPU CPU(C_DUMP, M_DUMP, A1, D1, C1, CLK);
    Cache Cache(A2, D1, C1, D2, C2, A1, RESET, C_DUMP, CLK);
    MemCTR MemCTR( D2, C2, A2, RESET, M_DUMP, CLK);
    int i;

    task automatic _wait(input int count);
        for (i = 0; i < count; i++) @(posedge CLK);
    endtask

    always #1 CLK = ~CLK;

endmodule
