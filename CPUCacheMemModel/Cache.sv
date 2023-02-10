`define MEM_SIZE (1 << 18)
`define CACHE_SIZE (1 << 11)
`define CACHE_LINE_SIZE (1 << 4)
`define CACHE_LINE_SIZE_BYTE (1 << 7)
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

module Cache(
    output reg[`ADDR2_BUS_SIZE - 1 : 0] A2,
    inout wire[`DATA1_BUS_SIZE - 1 : 0] D1, 
    inout wire[`CTR1_BUS_SIZE - 1 : 0] C1, 
    inout wire[`DATA2_BUS_SIZE - 1 : 0] D2, 
    inout wire[`CTR2_BUS_SIZE - 1 : 0] C2,
    input reg[`ADDR1_BUS_SIZE - 1 : 0] A1,
    input reg RESET, 
    input reg C_DUMP,
    input reg CLK  
    );

    reg[`DATA1_BUS_SIZE - 1 : 0] D1_1 = 'hz;
    reg[`CTR1_BUS_SIZE - 1 : 0] C1_1 = 'hz;
    reg[`DATA2_BUS_SIZE - 1 : 0] D2_1 = 'hz;
    reg[`CTR2_BUS_SIZE - 1 : 0] C2_1 = 'hz; 

    assign D1 = D1_1;
    assign C1 = C1_1;
    assign D2 = D2_1;
    assign C2 = C2_1;

    reg[2 + `CACHE_TAG_SIZE + `CACHE_LINE_SIZE_BYTE - 1 : 0] cache[`CACHE_LINE_COUNT - 1 : 0];
    reg[`CACHE_WAY - 1 : 0] cache_addr_use[`CACHE_SETS_COUNT - 1 : 0];
    reg[2 + `CACHE_TAG_SIZE + `CACHE_LINE_SIZE_BYTE - 1 : 0] line;
    reg[2 + `CACHE_TAG_SIZE + `CACHE_LINE_SIZE_BYTE - 1 : 0] data;
    reg[`CACHE_ADDR_SIZE - 1 : 0] addr;
    reg[`CACHE_TAG_SIZE - 1 : 0] tag;
    reg[(`CACHE_SET_SIZE * 2) - 1: 0] set;
    reg[`CACHE_OFFSET_SIZE - 1 : 0] offset;
    int fd;
    reg[15:0] ans_cpu[1:0];
    int cache_req = 0;
    int cache_miss = 0;
    reg[`CTR1_BUS_SIZE - 1 : 0] cur_c1;

    initial begin
        A2 = 0;
        reset();
    end

    always @(posedge CLK && RESET == 1) begin  
        reset();
    end
    
    always @(posedge CLK && C_DUMP == 1) begin
        fd = $fopen ("DUMP_C.ext", "w");
        for (int j = 0; j < `CACHE_LINE_COUNT; j++)
            $fdisplay (fd, "#%d# %b", j, cache[j]);
        $fclose(fd);
        $display("cache_hit, miss, sum",  cache_miss, cache_req - cache_miss, cache_req);
    end

    always @(posedge CLK) begin
        if (C1 === 1 || C1 === 2 || C1 === 3) begin
            cur_c1 = C1;
            addr = A1;
            _wait(1);
            addr = (addr << `CACHE_OFFSET_SIZE) + A1;
            _wait(1);
            C1_1 = 0;
            if (cur_c1 === 1) begin
                _READ(1);
            end else if (cur_c1 === 2) begin
                _READ(2);
            end else begin
                _READ(4);
            end 
        end else if (C1 === 5 || C1 === 6 || C1 === 7) begin
            cur_c1 = C1;
            addr = A1;
            data = D1;
            _wait(1);
            addr = (addr << `CACHE_OFFSET_SIZE) + A1;
            if (cur_c1 === 5) begin
                _wait(1);
                C1_1 = 0;
                _WRITE(1);
            end else if (cur_c1 === 6) begin
                _wait(1);
                C1_1 = 0;
                _WRITE(2);
            end else begin
                data = (data << 16) + D1;
                _wait(1);
                C1_1 = 0;
                _WRITE(4);
            end
            D1_1 = 'hz;
        end else if (C1 === 4) begin
            addr = A1;
            _wait(1);
            addr = (addr << `CACHE_OFFSET_SIZE) + A1;
            _wait(1);
            C1_1 = 0;
            _INVALIDATE_LINE();
            C1_1 = 'hz;
        end
    end
    
    task automatic _wait(input count);
        for (int p = 0; p < count; p++) @(posedge CLK);
    endtask

    task automatic reset();
        for (int r = 0; r < `CACHE_LINE_COUNT; r++) begin
            cache[r] = 0;
        end
        for (int r = 0; r < `CACHE_LINE_COUNT; r++) begin
            cache_addr_use[r][0] = 0;
            cache_addr_use[r][1] = 0;
        end
    endtask

    task automatic _READ(input int count_bytes);
        _wait(4);
        read_in_cache(count_bytes);
        C1_1 = 7;
        _wait(1);
        answer_CPU(count_bytes);
        C1_1 = 'hz;
    endtask

    task automatic _WRITE(input int count_bytes);
        _wait(4);
        write_in_cache(count_bytes);
        C1_1 = 7;
        _wait(1);
        C1_1 = 'hz;
    endtask

    task automatic read_in_cache(input int count_bytes);
        ans_cpu[0] = 0;
        ans_cpu[1] = 0;
        tag = addr >> (`CACHE_SET_SIZE + `CACHE_OFFSET_SIZE);
        set = (addr >> `CACHE_OFFSET_SIZE) % (1 << `CACHE_SET_SIZE);
        offset = addr % (1 << `CACHE_OFFSET_SIZE);
        if (cache[(set << 1)][`CACHE_LINE_SIZE_BYTE + `CACHE_TAG_SIZE - 1 : `CACHE_LINE_SIZE_BYTE] == tag 
        && cache[(set << 1)][`CACHE_LINE_SIZE_BYTE + `CACHE_TAG_SIZE + 1] == 1) begin
            cache_req++;
            cache_addr_use[set][0] = 1;
            cache_addr_use[set][1] = 0;
            fill_ans_cpu(0, count_bytes);
        end else if (cache[(set << 1) + 1][`CACHE_LINE_SIZE_BYTE + `CACHE_TAG_SIZE - 1 : `CACHE_LINE_SIZE_BYTE] == tag 
        && cache[(set << 1) + 1][`CACHE_LINE_SIZE_BYTE + `CACHE_TAG_SIZE + 1] == 1) begin
            cache_req++;
            cache_addr_use[set][0] = 0;
            cache_addr_use[set][1] = 1;
            fill_ans_cpu(1, count_bytes);
        end else begin
            cache_miss++;
            read_in_mem();
            _wait(1);
            read_in_cache(count_bytes);
        end
    endtask

    task automatic fill_ans_cpu(int num_in_set, int count_bytes);
        if (count_bytes == 1) begin
            for (int v = 0; v < 8; v++) begin
                ans_cpu[0] = ans_cpu[0] + ((cache[(set << 1) + num_in_set][offset * 8 + v]) << v);
            end
        end else if (count_bytes == 2) begin
            for (int v = 0; v < 8; v++) begin
                ans_cpu[0] = ans_cpu[0] + ((cache[(set << 1) + num_in_set][(offset + 1) * 8 + v]) << v);
            end
            ans_cpu[0] = ans_cpu[0] << 8;
            for (int v = 0; v < 8; v++) begin
                ans_cpu[0] = ans_cpu[0] + ((cache[(set << 1) + num_in_set][offset * 8 + v]) << v);
            end
        end else begin
            int new_set = set;
            new_set = set << 1;
            for (int u = 0; u < 2; u++) begin
                for (int v = 0; v < 8; v++) begin
                    ans_cpu[u] = ans_cpu[u] + ((cache[new_set + num_in_set][(offset + 1 + u * 2) * 8 + v]) << v);
                end
                ans_cpu[u] = ans_cpu[u] << 8;
                for (int v = 0; v < 8; v++) begin
                    ans_cpu[u] = ans_cpu[u] + ((cache[new_set + num_in_set][(offset + u * 2) * 8 + v]) << v);
                end
            end
        end
    endtask
    
    task automatic read_in_mem();
        C2_1 = 2;
        A2 = addr >> `CACHE_OFFSET_SIZE;
        _wait(1);
        C2_1 = 'hz;
        while (!(C2 === 1)) _wait(1);
        line = 0;
        for (int a = 0; a < 8; a++) begin
            line = line + (D2 << (16 * a));
            _wait(1);
        end
        if (cache_addr_use[set][0] == 0) begin
            if (cache[(set << 1)][`CACHE_LINE_SIZE_BYTE + `CACHE_TAG_SIZE] == 1 && 
            cache[(set << 1)][`CACHE_LINE_SIZE_BYTE + `CACHE_TAG_SIZE + 1] == 1) begin
                reg[`CACHE_TAG_SIZE - 1 : 0] new_tag = (cache[(set << 1)][`CACHE_LINE_SIZE_BYTE + `CACHE_TAG_SIZE - 1 : `CACHE_LINE_SIZE_BYTE]);
                write_in_mem(0, set + (new_tag << `CACHE_SET_SIZE));
                _wait(1);
            end
            cache[(set << 1)][`CACHE_LINE_SIZE_BYTE + `CACHE_TAG_SIZE - 1 : 0] = (tag << `CACHE_LINE_SIZE_BYTE) + line;
            cache[(set << 1)][`CACHE_LINE_SIZE_BYTE + `CACHE_TAG_SIZE + 1] = 1;
            cache[(set << 1)][`CACHE_LINE_SIZE_BYTE + `CACHE_TAG_SIZE] = 0;
            cache_addr_use[set][0] = 1;
            cache_addr_use[set][1] = 0;
        end else begin
            if (cache[(set << 1) + 1][`CACHE_LINE_SIZE_BYTE + `CACHE_TAG_SIZE] == 1 &&
            cache[(set << 1) + 1][`CACHE_LINE_SIZE_BYTE + `CACHE_TAG_SIZE + 1] == 1) begin
                reg[`CACHE_TAG_SIZE - 1 : 0] new_tag = (cache[(set << 1) + 1][`CACHE_LINE_SIZE_BYTE + `CACHE_TAG_SIZE - 1 : `CACHE_LINE_SIZE_BYTE]);
                write_in_mem(1, set + (new_tag << `CACHE_SET_SIZE));
                _wait(1);
            end
            cache[(set << 1) + 1][`CACHE_LINE_SIZE_BYTE + `CACHE_TAG_SIZE - 1 : 0] = (tag << `CACHE_LINE_SIZE_BYTE) + line;
            cache[(set << 1) + 1][`CACHE_LINE_SIZE_BYTE + `CACHE_TAG_SIZE + 1] = 1;
            cache[(set << 1) + 1][`CACHE_LINE_SIZE_BYTE + `CACHE_TAG_SIZE] = 0;
            cache_addr_use[set][1] = 1;
            cache_addr_use[set][0] = 0;
        end
    endtask

    task automatic answer_CPU(input int count_bytes); //+
        C1_1 = 7;
        if (count_bytes == 1 || count_bytes == 2) begin
            D1_1 = ans_cpu[0];
            _wait(1);
        end else begin
            D1_1 = ans_cpu[0];
            _wait(1);
            D1_1 = ans_cpu[1];
            _wait(1);
        end
        D1_1 = 'hz;      
        C1_1 = 'hz;
    endtask

    task automatic write_in_cache(input int count_bytes);
        tag = addr >> (`CACHE_SET_SIZE + `CACHE_OFFSET_SIZE);
        set = (addr >> `CACHE_OFFSET_SIZE) % (1 << `CACHE_SET_SIZE);
        offset = addr % (1 <<`CACHE_OFFSET_SIZE);
        if (cache[(set << 1)][`CACHE_LINE_SIZE_BYTE + `CACHE_TAG_SIZE - 1 : `CACHE_LINE_SIZE_BYTE] === tag
        && cache[(set << 1)][`CACHE_LINE_SIZE_BYTE + `CACHE_TAG_SIZE + 1] == 1) begin
            cache_req++;
            cache[(set << 1)][`CACHE_LINE_SIZE_BYTE + `CACHE_TAG_SIZE] = 1;
            cache_addr_use[set][0] = 1;
            cache_addr_use[set][1] = 0;
            for (int b = 0; b < count_bytes; b++) begin
                for (int c = 0; c < 8; c++) begin
                    cache[(set << 1)][(offset + b) * 8 + c] = data[b * 8 + c];
                end
            end
        end else if (cache[(set << 1) + 1][`CACHE_LINE_SIZE_BYTE + `CACHE_TAG_SIZE - 1 : `CACHE_LINE_SIZE_BYTE] === tag
        && cache[(set << 1) + 1][`CACHE_LINE_SIZE_BYTE + `CACHE_TAG_SIZE + 1] == 1) begin
            cache_req++;
            cache[(set << 1) + 1][`CACHE_LINE_SIZE_BYTE + `CACHE_TAG_SIZE] = 1;
            cache_addr_use[set][0] = 0;
            cache_addr_use[set][1] = 1;
            for (int b = 0; b < count_bytes; b++) begin
                for (int c = 0; c < 8; c++) begin
                    cache[(set << 1) + 1][(offset + b) * 8 + c] = data[b * 8 + c];
                end
            end 
        end else begin
            cache_miss++;
            read_in_mem();
            _wait(1);
            write_in_cache(count_bytes);
        end
    endtask

    task automatic write_in_mem(input num_in_set, reg[`CACHE_TAG_SIZE + `CACHE_SET_SIZE - 1 : 0] addr);
        A2 = addr;
        C2_1 = 3;
        for (int t = 0; t < (`CACHE_LINE_SIZE / 2); t++) begin
            reg[`DATA2_BUS_SIZE - 1 : 0] data_1 = 0;
            for (int s = 0; s < 16; s++) begin
                data_1 += ((cache[(set << 1) + num_in_set][t * 16 + s]) << s);
            end
            D2_1 = data_1;
            _wait(1);
            A2 = 'hz;
            C2_1 = 'hz;
        end
        D2_1 = 'hz;
        while (!(C2 === 1)) _wait(1);
        _wait(1);
        C2_1 = 0;
    endtask

    task automatic _INVALIDATE_LINE();
        tag = addr >> (`CACHE_SET_SIZE + `CACHE_OFFSET_SIZE);
        set = (addr >> `CACHE_OFFSET_SIZE) % (1 << `CACHE_SET_SIZE);
        offset = addr % `CACHE_OFFSET_SIZE;
        if (cache[(set << 1)][`CACHE_LINE_SIZE_BYTE + `CACHE_TAG_SIZE - 1 : `CACHE_LINE_SIZE_BYTE] == tag) begin
            if (cache[(set << 1)][`CACHE_LINE_SIZE_BYTE + `CACHE_TAG_SIZE] == 1 && 
            cache[(set << 1)][`CACHE_LINE_SIZE_BYTE + `CACHE_TAG_SIZE + 1] == 1) begin
                reg[`CACHE_TAG_SIZE - 1 : 0] new_tag = (cache[(set << 1)][`CACHE_LINE_SIZE_BYTE + `CACHE_TAG_SIZE - 1 : `CACHE_LINE_SIZE_BYTE]);
                write_in_mem(0, set + ( new_tag << `CACHE_SET_SIZE));
                _wait(1);
            end
            cache_addr_use[set][0] = 1;
            cache_addr_use[set][1] = 0;
            cache[(set << 1)] = 0;
        end else if (cache[(set << 1) + 1][`CACHE_LINE_SIZE_BYTE + `CACHE_TAG_SIZE - 1 : `CACHE_LINE_SIZE_BYTE] == tag) begin
            if (cache[(set << 1) + 1][`CACHE_LINE_SIZE_BYTE + `CACHE_TAG_SIZE] == 1 && 
            cache[(set << 1) + 1][`CACHE_LINE_SIZE_BYTE + `CACHE_TAG_SIZE + 1] == 1) begin
                reg[`CACHE_TAG_SIZE - 1 : 0] new_tag = (cache[(set << 1) + 1][`CACHE_LINE_SIZE_BYTE + `CACHE_TAG_SIZE - 1 : `CACHE_LINE_SIZE_BYTE]);
                write_in_mem(0, set + ( new_tag << `CACHE_SET_SIZE));
                _wait(1);
            end
            cache_addr_use[set][0] = 0;
            cache_addr_use[set][1] = 1;
            cache[(set << 1) + 1] = 0;
        end
    endtask
      
endmodule