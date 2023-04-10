`timescale 1ps/1ps

module main();

    initial begin
        $dumpfile("cpu.vcd");
        $dumpvars(0,main);
    end

    // clock
    wire clk;
    clock c0(clk);

    reg halt = 0;

    counter ctr(halt,clk);

    // PC
    reg [15:0]pc = 16'h0000;


    //Memory Wires

    // read Instructions from memory
    wire [15:0]fetchOutputInstruction;

    //M0 input wire
    wire [15:1]m0InputInstruction;

    wire [15:0]m1OutputInstruction;

    //Mem Writing Wires
    wire memWen; 
    wire [15:1]memWaddr; 
    wire [15:0]memWdata; 


    // memory
    mem mem(clk,
         pc[15:1],fetchOutputInstruction,
         m0InputInstruction,m1OutputInstruction,
         memWen,memWaddr,memWdata);



    //Register Wires
    wire [3:0]raddr0_;
    wire [15:0]rdata0;
    wire [3:0]raddr1_;
    wire [15:0]rdata1;
    wire regWen;
    wire [3:0]regWaddr;
    wire [15:0]regWdata;




    // registers
    regs regs(clk,
        raddr0_,rdata0,
        raddr1_,rdata1,
        regWen,regWaddr,regWdata);



    //PC

    always @(posedge clk) begin
        if (pc == 14) begin
            halt <= 1;
        end
        //$write("pc = %d\n",pc);
        pc <= pc + 2;
    end

    //F0
    reg validF0 = 0;
    reg [15:0] f0_pc = 16'h0000;
    always @(posedge clk) begin
        //$write("f0_pc = %d\n",f0_pc);
        f0_pc <= pc;
    end

    //F1
    reg validF1 = 0;
    reg [15:0] f1_pc = 16'h0000;
    //reg [15:0] f1_instruction = 16'h0000;
    always @(posedge clk) begin
        //$write("f1_pc = %d\n",f1_pc);
        f1_pc <= f0_pc;
        //move this to the next stage 
        //f1_instruction <= fetchOutputInstruction;
        //$write("f1_instruction = %d\n",f1_instruction);
    end

    //Decode Logic 
    //Decompose the Instruction
    wire [3:0] opcode = fetchOutputInstruction[15:12];
    wire [3:0] ra = fetchOutputInstruction[11:8];
    wire [3:0] rb = fetchOutputInstruction[7:4];
    wire [3:0] rt = fetchOutputInstruction[3:0];
    wire [7:0] d_i = fetchOutputInstruction[11:4];

    //Decode the operator 
    wire d_is_sub = opcode == 4'b0000;
    wire d_is_movl = opcode == 4'b1000;
    wire d_is_movh = opcode == 4'b1001;
    wire d_is_jmp = opcode == 4'b1110;
    wire d_is_mem = opcode == 4'b1111;

    wire d_is_jz = d_is_jmp && rb == 4'b0000;
    wire d_is_jnz = d_is_jmp && rb == 4'b0001;
    wire d_is_js = d_is_jmp && rb == 4'b0010;
    wire d_is_jns = d_is_jmp && rb == 4'b0011;

    wire d_is_ld = d_is_mem && rb==4'b0000;
    wire d_is_st = d_is_mem && rb==4'b0001;

    wire d_is_invalid = !(d_is_sub|d_is_movl|d_is_movh|d_is_jmp|d_is_mem|d_is_jz|d_is_jnz|d_is_js|d_is_jns|d_is_ld|d_is_st);

    //Feed into register ports
    
    assign raddr0_ = ra;
    assign raddr1_ =  d_is_sub ? rb : rt;
    
    

    //Register Phase
    reg validR = 0;
    reg r_is_sub;
    reg r_is_movl;
    reg r_is_movh;
    reg r_is_jmp;
    reg r_is_mem;
    reg [3:0] r_rt;
    reg [7:0] r_i;

    reg r_is_jz;
    reg r_is_jnz;
    reg r_is_js;
    reg r_is_jns;

    reg r_is_ld;
    reg r_is_st;
    reg r_is_invalid;
    reg [15:0] r_pc = 16'h0000;


    reg [15:0] r_rdata1;
    reg [15:0] r_rdata0;



    always @(posedge clk) begin
        r_pc <= f1_pc;
        r_is_sub<= d_is_sub;
        r_is_movl<= d_is_movl;
        r_is_movh<= d_is_movh;
        r_i<= d_i;
        r_is_jz<= d_is_jz;
        r_is_jnz<= d_is_jnz;
        r_is_js<= d_is_js;
        r_is_jns<= d_is_jns;
        r_is_ld<= d_is_ld;
        r_is_st<= d_is_st;
        r_is_invalid = d_is_invalid;
        r_rdata1 <= rdata1;
        r_rdata0 <= rdata0;
        r_rt <= rt;
        if(r_rt==4'b0000)
            $write("%c",r_i);
    end

    //assign regWen = r_is_movl;
    //assign regWaddr = r_rdata1;
    //assign regWdata = r_i;
   //$write("r_i = %d\n",r_i);









endmodule
