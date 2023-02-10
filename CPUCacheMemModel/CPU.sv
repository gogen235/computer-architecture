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

`define SIZE_A 1
`define SIZE_B 2
`define SIZE_C 4

`define M 64
`define N 60
`define K 32

module CPU(output reg C_DUMP,
    output reg M_DUMP,
    output reg[`ADDR1_BUS_SIZE - 1 : 0] A1,
    inout wire[`DATA1_BUS_SIZE - 1 : 0] D1, 
    inout wire[`CTR1_BUS_SIZE - 1 : 0] C1, 
    input reg CLK
    );
    reg[`DATA1_BUS_SIZE - 1 : 0] D1_1 = 'hz;
    reg[`CTR1_BUS_SIZE - 1 : 0] C1_1 = 'hz;

    assign D1 = D1_1;
    assign C1 = C1_1;

    int count_tact = 0;
    int data_a = 0;
    int data_b = 0;
    int data_c = 0;
    int s = 0;
    int pa;
    int pb;
    int pc;

    task automatic _wait(input int count);
        for (int i = 0; i < count; i++) @(posedge CLK);
    endtask

    task automatic READ8(int x, int k);
        C1_1 = 1;
        A1 = (pa + k * `SIZE_A) >> `CACHE_OFFSET_SIZE;
        _wait(1);
        A1 = (pa + k * `SIZE_A) % (1 << `CACHE_OFFSET_SIZE);
        _wait(1);
        C1_1 = 'hz;
        while (!(C1 === 7)) _wait(1);
        _wait(1);
        data_a = D1;
        _wait(1);
        C1_1 = 0;
        _wait(1);
    endtask

    task automatic READ16(int x, int k);
        C1_1 = 2;
        A1 = (pb + x * `SIZE_B) >> `CACHE_OFFSET_SIZE;
        _wait(1);
        A1 = (pb + x * `SIZE_B) % (1 << `CACHE_OFFSET_SIZE);
        _wait(1);
        C1_1 = 'hz;
        while (!(C1 === 7)) _wait(1);
        _wait(1);
        data_b = D1;
        _wait(1);
        C1_1 = 0;
        _wait(1);
    endtask

    task automatic READ32(int aaaa);
        C1_1 = 3;
        A1 = aaaa >> `CACHE_OFFSET_SIZE;
        _wait(1);
        A1 = aaaa % (1 << `CACHE_OFFSET_SIZE);
        _wait(1);
        C1_1 = 'hz;
        while (!(C1 === 7)) _wait(1);
        _wait(1);
        data_c = D1;
        _wait(1);
        data_c += (D1 << 16);
        _wait(1);
        C1_1 = 0;
        _wait(1);
    endtask

    task automatic WRITE8(int x);
        C1_1 = 7;
        D1_1 = s;
        A1 = (pc + x * `SIZE_C) >> `CACHE_OFFSET_SIZE;
        _wait(1);
        A1 = (pc + x * `SIZE_C) % (1 << `CACHE_OFFSET_SIZE);
        _wait(1);
        C1_1 = 'hz;
        D1_1 = 'hz;
        while (!(C1 === 7)) _wait(1);
        _wait(1);
        C1_1 = 0;
    endtask

    task automatic WRITE16(int x);
        C1_1 = 7;
        D1_1 = s;
        A1 = (pc + x * `SIZE_C) >> `CACHE_OFFSET_SIZE;
        _wait(1);
        A1 = (pc + x * `SIZE_C) % (1 << `CACHE_OFFSET_SIZE);
        _wait(1);
        C1_1 = 'hz;
        D1_1 = 'hz;
        while (!(C1 === 7)) _wait(1);
        _wait(1);
        C1_1 = 0;
    endtask

    task automatic WRITE32(int x);
        C1_1 = 7;
        D1_1 = s % (1 << 16);
        A1 = (pc + x * `SIZE_C) >> `CACHE_OFFSET_SIZE;
        _wait(1);
        D1_1 = (s >> 16);
        A1 = (pc + x * `SIZE_C) % (1 << `CACHE_OFFSET_SIZE);
        _wait(1);
        C1_1 = 'hz;
        D1_1 = 'hz;
        while (!(C1 === 7)) _wait(1);
        _wait(1);
        C1_1 = 0;
    endtask

    initial begin
        C_DUMP = 0;
        M_DUMP = 0;
        pa = 0;
        _wait(1);//int8 *pa = a;
        pc = `M * `K * `SIZE_A + `N * `K * `SIZE_B;
        _wait(1); //int32 *pc = c;
        _wait(1); // initialization y
        for (int y = 0; y < `M; y++) begin
            _wait(1); //start of a new loop iteration
            _wait(1); // initialization x
            for (int x = 0; x < `N; x++) begin
                _wait(1); //start of a new loop iteration
                s = 0;
                _wait(1); //new variable
                pb = `M * `K * `SIZE_A;
                _wait(1); //int16 *pb = b;
                _wait(1); // initialization k
                for (int k = 0; k < `K; k++) begin
                    _wait(1); //start of a new loop iteration
                    READ8(x, k); // a
                    READ16(x, k); // b
                    s += data_a * data_b;
                    _wait(1 + 5 + 1 + 1); // s += pa[k] * pb[x];
                    pb += `N * `SIZE_B;
                    _wait(1); // +
                end
                _wait(1); // pc[x] = s;
                WRITE32(x); // c
            end
            pa += `K * `SIZE_A;
            _wait(1); //pa += K;
            pc += `N * `SIZE_C;
            _wait(1); //pc += N;
        end
        _wait(1); //exit out function mmul;
        $display(count_tact);
        C_DUMP = 1;
        _wait(1);
        C_DUMP = 0;

        // pc = `M * `K * `SIZE_A + `N * `K * `SIZE_B;
        // for (int r = 0; r < `M; r++) begin
        //     for (int y = 0; y < `N; y++) begin
        //         READ32(pc);
        //         $display("c = %0d, addr_c = %d", data_c, pc);
        //         pc += 4;
        //     end 
        //     $finish;
        // end

        $finish;
    end

    always @(posedge CLK) count_tact++;
 
endmodule