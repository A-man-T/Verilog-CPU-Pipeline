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
        if (pc == 10) begin
            halt <= 1;
        end
        $write("pc = %d\n",pc);
        pc <= pc + 2;
    end

    //F0
    reg validF0 = 1;
    reg [15:0] f0_pc = 16'h0000;
    always @(posedge clk) begin
        $write("f0_pc = %d\n",f0_pc);
        f0_pc <= pc;
    end

    //F1
    reg validF1 = 1;
    reg [15:0] f1_pc = 16'h0000;
    //reg [15:0] f1_instruction = 16'h0000;
    always @(posedge clk) begin
        $write("f1_pc = %d\n",f1_pc);
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




    //Register Phase








endmodule
