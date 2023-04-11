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
    wire flush;

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
         flush ? flushTarget[15:1] : pc[15:1],fetchOutputInstruction,
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




    //F0 + PC
    reg validF0 = 1;
    always @(posedge clk) begin

        //$write("pc = %d\n",pc);
        pc <= flush ? flushTarget+2: pc + 2;
    end

    //F1
    reg validF1 = 0;
    reg [15:0] f1_pc;
    //reg [15:0] f1_instruction = 16'h0000;
    always @(posedge clk) begin
        //$write("f1_pc = %d\n",f1_pc);
        f1_pc <= pc;
        validF1 <= validF0;
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

    wire d_is_invalid = ~(d_is_sub|d_is_movl|d_is_movh|d_is_jz|d_is_jnz|d_is_js|d_is_jns|d_is_ld|d_is_st);

    //Feed into register ports

    wire [3:0] r2 = d_is_sub ? rb : rt;
    
    assign raddr0_ = ra;
    assign raddr1_ = r2;


    reg [15:0] d_pc;
    reg validD = 0;
    always @(posedge clk) begin
        d_pc <= f1_pc;
        validD <= validF1 & !flush;
    end



    //Memory Phase
    reg validM = 0;
    reg m_is_sub;
    reg m_is_movl;
    reg m_is_movh;
    reg m_is_jmp;
    reg m_is_mem;
    reg [3:0] m_rt;
    reg [7:0] m_i;

    reg m_is_jz;
    reg m_is_jnz;
    reg m_is_js;
    reg m_is_jns;

    reg m_is_ld;
    reg m_is_st;
    reg m_is_invalid;
    reg [15:0] m_pc;


    wire [15:0] m_rdata1 = m_r2==4'b0000 ? 0: rdata1;
    wire [15:0] m_rdata0 = m_ra==4'b0000 ? 0 : rdata0;

    reg [3:0] m_ra;
    reg [3:0] m_rb;
    reg [3:0] m_r2; 
    

    always @(posedge clk) begin
        validM <= validD &!flush;
        m_r2 <= r2;
        m_is_jmp <= d_is_jmp;
        m_pc <= d_pc;
        m_is_sub<= d_is_sub;
        m_is_movl<= d_is_movl;
        m_is_movh<= d_is_movh;
        m_i<= d_i;
        m_is_jz<= d_is_jz;
        m_is_jnz<= d_is_jnz;
        m_is_js<= d_is_js;
        m_is_jns<= d_is_jns;
        m_is_ld<= d_is_ld;
        m_is_st<= d_is_st;
        m_is_invalid <= d_is_invalid;


        m_rt <= rt;
        m_ra <= ra;
        m_rb <= rb;     
   

    end

    assign m0InputInstruction = m_rdata0[15:1];

    //Execute

    reg validE = 0;
    reg [3:0] e_r2; 
    reg e_is_sub;
    reg e_is_movl;
    reg e_is_movh;
    reg e_is_jmp;
    reg e_is_mem;
    reg [3:0] e_rt;
    reg [7:0] e_i;

    reg e_is_jz;
    reg e_is_jnz;
    reg e_is_js;
    reg e_is_jns;

    reg e_is_ld;
    reg e_is_st;
    reg e_is_invalid;
    reg [15:0] e_pc;


    reg [15:0] e_rdata1;
    reg [15:0] e_rdata0;

    wire e_rdata1WIRE = forwardWtoE && w_rt == e_r2 ? w_output:e_rdata1;
    wire e_rdata0WIRE = forwardWtoE && w_rt == e_ra ? w_output:e_rdata0;

    reg [3:0] e_ra;
    reg [3:0] e_rb;

    wire [15:0] e_computed_value;

    always @(posedge clk) begin
        e_r2 <= m_r2;
        validE<=validM & !flush;
        e_is_jmp <= m_is_jmp;
        e_pc <= m_pc;
        e_is_sub<= m_is_sub;
        e_is_movl<= m_is_movl;
        e_is_movh<= m_is_movh;
        e_i<= m_i;
        e_is_jz<= m_is_jz;
        e_is_jnz<= m_is_jnz;
        e_is_js<= m_is_js;
        e_is_jns<= m_is_jns;
        e_is_ld<= m_is_ld;
        e_is_st<= m_is_st;
        e_is_invalid <= m_is_invalid;
        e_rdata1 <= m_rdata1;
        e_rdata0 <= m_rdata0;
        e_rt <= m_rt;
        e_ra <= m_ra;
        e_rb <= m_rb; 
        halt <= e_is_invalid & validE;           
    end
    
    //fix the computed values for jump statements
    // I think its fixed?
    assign e_computed_value = e_is_sub ? e_rdata0 - e_rdata1:
    e_is_movl ? {{8{e_i[7]}}, e_i} :
    e_is_movh ? {e_i,e_rdata1[7:0]} :
    e_is_jz ? e_rdata0 == 0 :
    e_is_jnz ? e_rdata0 != 0 :
    e_is_js ? e_rdata0[15] == 1 :
    e_is_jns ? e_rdata0[15] == 0 :
    e_is_st ? e_rdata1 : 0;



    
    //what are flush conditions? 

    assign flush = validE & e_is_jmp & e_computed_value == 1 ? 1 : 0;
    wire[15:0] flushTarget = flush ? e_rdata1 : e_pc;

    assign memWen = e_is_st&validE;
    assign memWaddr = e_rdata0[15:1];
    assign memWdata = e_computed_value;



    
    
    
    
    //Writeback
    reg validW = 0;
    reg [3:0] w_r2; 
    reg w_is_sub;
    reg w_is_movl;
    reg w_is_movh;
    reg w_is_jmp;
    reg w_is_mem;
    reg [3:0] w_rt;
    reg [7:0] w_i;

    reg w_is_jz;
    reg w_is_jnz;
    reg w_is_js;
    reg w_is_jns;

    reg w_is_ld;
    reg w_is_st;
    reg w_is_invalid;
    reg [15:0] w_pc;


    reg [15:0] w_rdata1;
    reg [15:0] w_rdata0;

    reg [3:0] w_ra;
    reg [3:0] w_rb;

    reg [15:0] w_computed_value;
    wire[15:0] w_output = w_is_ld ? m1OutputInstruction : w_computed_value;


    always @(posedge clk) begin
        validW<=validE;
        w_r2 <= e_r2;
        w_is_jmp <= e_is_jmp;
        w_pc <= e_pc;
        w_is_sub<= e_is_sub;
        w_is_movl<= e_is_movl;
        w_is_movh<= e_is_movh;
        w_i<= e_i;
        w_is_jz<= e_is_jz;
        w_is_jnz<= e_is_jnz;
        w_is_js<= e_is_js;
        w_is_jns<= e_is_jns;
        w_is_ld<= e_is_ld;
        w_is_st<= e_is_st;
        w_is_invalid <= e_is_invalid;
        w_rdata1 <= e_rdata1;
        w_rdata0 <= e_rdata0;
        w_rt <= e_rt;
        w_ra <= e_ra;
        w_rb <= e_rb;    
        w_computed_value <= e_computed_value;

        if(w_rt==4'b0000 &&  ~(w_is_jmp|w_is_st) &&validW)
           $write("%c",w_output[7:0]);


    end

    wire forwardWtoE = validW && (w_rt == e_ra || w_rt ==e_rt)? 1: 0;

    
    assign regWen = ~(w_is_jmp|w_is_st)&validW;
    assign regWaddr = w_rt;
    assign regWdata = w_output;




    














   // r_rdataToWrite = r_is_sub ? r_rdata1 - r_rdata0 : 

   //m0InputInstruction = r_is_ld ? r_ra












endmodule
