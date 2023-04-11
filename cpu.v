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
         pc[15:1],fetchOutputInstruction,
         m0InputInstruction[15:1],m1OutputInstruction,
         memWen,memWaddr[15:1],memWdata);



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
    reg validF0 = 0;
    always @(posedge clk) begin

        //$write("pc = %d\n",pc);
        pc <= flushTarget;
        validF0 <= 1 & !flush;
    end

    //F1
    reg validF1 = 0;
    reg [15:0] f1_pc;
    //reg [15:0] f1_instruction = 16'h0000;
    always @(posedge clk) begin
        //$write("f1_pc = %d\n",f1_pc);
        f1_pc <= pc;
        validF1 <= validF0 & !flush;
        //move this to the next stage 
        //f1_instruction <= fetchOutputInstruction;
        //$write("f1_instruction = %d\n",f1_instruction);
    end

    //Decode Logic 
    //Decompose the Instruction
    wire [3:0] de_opcode = fetchOutputInstruction[15:12];
    wire [3:0] de_ra = fetchOutputInstruction[11:8];
    wire [3:0] de_rb = fetchOutputInstruction[7:4];
    wire [3:0] de_rt = fetchOutputInstruction[3:0];
    wire [7:0] de_i = fetchOutputInstruction[11:4];

    //Decode the operator 
    wire de_is_sub = de_opcode == 4'b0000;
    wire de_is_movl = de_opcode == 4'b1000;
    wire de_is_movh = de_opcode == 4'b1001;
    wire de_is_jmp = de_opcode == 4'b1110;
    wire de_is_mem = de_opcode == 4'b1111;

    wire de_is_jz = de_is_jmp && de_rb == 4'b0000;
    wire de_is_jnz = de_is_jmp && de_rb == 4'b0001;
    wire de_is_js = de_is_jmp && de_rb == 4'b0010;
    wire de_is_jns = de_is_jmp && de_rb == 4'b0011;

    wire de_is_ld = de_is_mem && de_rb==4'b0000;
    wire de_is_st = de_is_mem && de_rb==4'b0001;

    wire de_is_invalid = ~(de_is_sub|de_is_movl|de_is_movh|de_is_jz|de_is_jnz|de_is_js|de_is_jns|de_is_ld|de_is_st);

    //Feed into register ports

    wire [3:0] r2 = de_is_sub ? de_rb : de_rt;
    
    assign raddr0_ = de_ra;
    assign raddr1_ = r2;

    reg d_is_sub;
    reg d_is_movl;
    reg d_is_movh;
    reg d_is_jmp;
    reg d_is_mem;
    reg [3:0] d_rt;
    reg [7:0] d_i;

    reg d_is_jz;
    reg d_is_jnz;
    reg d_is_js;
    reg d_is_jns;

    reg d_is_ld;
    reg d_is_st;
    reg d_is_invalid;

    reg [3:0] d_ra;
    reg [3:0] d_rb;
    reg [3:0] d_r2; 

    reg [15:0] d_pc;
    reg validD = 0;
    always @(posedge clk) begin
        d_pc <= f1_pc;
        validD <= validF1 & !flush;
        d_r2 <= r2;
        d_is_jmp <= de_is_jmp;
        d_is_sub<= de_is_sub;
        d_is_movl<= de_is_movl;
        d_is_movh<= de_is_movh;
        d_i<= de_i;
        d_is_jz<= de_is_jz;
        d_is_jnz<= de_is_jnz;
        d_is_js<= de_is_js;
        d_is_jns<= de_is_jns;
        d_is_ld<= de_is_ld;
        d_is_st<= de_is_st;
        d_is_invalid <= de_is_invalid;


        d_rt <= de_rt;
        d_ra <= de_ra;
        d_rb <= de_rb;
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


    wire [15:0] mem_rdata1 = d_r2==4'b0000 ? 0: rdata1;
    wire [15:0] mem_rdata0 = d_ra==4'b0000 ? 0 : rdata0;
    assign m0InputInstruction = mem_rdata0[15:1];


    reg [3:0] m_ra;
    reg [3:0] m_rb;
    reg [3:0] m_r2; 
    
    reg [15:0] m_rdata1;
    reg [15:0] m_rdata0;

    always @(posedge clk) begin
        validM <= validD &!flush;
        m_r2 <= d_r2;
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

        m_rdata1 <= mem_rdata1;
        m_rdata0 <= mem_rdata0;


        m_rt <= d_rt;
        m_ra <= d_ra;
        m_rb <= d_rb;     
   

    end

    
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

    

    reg [3:0] e_ra;
    reg [3:0] e_rb;


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
        if(e_rt==4'b0000 &&  ~(e_is_jmp|e_is_st) &&validE)
           $write("%c",e_output[7:0]);    

    end
    
    //fix the computed values for jump statements
    // I think its fixed?
    wire [15:0]e_computed_value = e_is_sub ? e_rdata0 - e_rdata1:
    e_is_movl ? {{8{e_i[7]}}, e_i} :
    e_is_movh ? {e_i,e_rdata1[7:0]} :
    e_is_jz ? e_rdata0 == 0 :
    e_is_jnz ? e_rdata0 != 0 :
    e_is_js ? e_rdata0[15] == 1 :
    e_is_jns ? e_rdata0[15] == 0 :
    e_is_st ? e_rdata1 : 0;



    
    //what are flush conditions? 

    assign flush = (validE & e_is_jmp & e_computed_value  == 1 ) | (e_is_invalid & validE) ? 1 : 0;
    wire[15:0] flushTarget = flush ? e_rdata1 : pc + 2;

    assign memWen = e_is_st & validE;
    assign memWaddr = e_rdata0[15:1];
    assign memWdata = e_computed_value;

    wire[15:0] e_output = e_is_ld ? m1OutputInstruction : e_computed_value;



   
        

    //wire forwardWtoE = validW && (w_rt == e_ra || w_rt ==e_rt)? 1: 0;

    
    assign regWen = ~(e_is_jmp|e_is_st)&validE;
    assign regWaddr = e_rt;
    assign regWdata = e_output;

    always @(posedge clk) begin
        if (e_is_invalid & validE) begin
            halt <= 1;
        end
    end


    














   // r_rdataToWrite = r_is_sub ? r_rdata1 - r_rdata0 : 

   //m0InputInstruction = r_is_ld ? r_ra












endmodule
