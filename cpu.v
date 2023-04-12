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
    wire [15:0]m0InputInstruction;

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

    //Checks if PC is misaligned
    wire pc_is_mis = pc[0];

    //F0 + PC
    reg validF0 = 0;
    reg [15:0] f0_pc;
    always @(posedge clk) begin
        //FlushTarget always contains the next PC
        f0_pc <= pc;
        pc <= flushTarget;
        validF0 <= 1 & !flush;
    end

    //F1
    //Made because memory takes 2 cycles
    reg validF1 = 0;
    reg [15:0] f1_pc;
    always @(posedge clk) begin
        f1_pc <= f0_pc;
        validF1 <= validF0 & !flush;
    end

    //Deals with misaligned PC
    wire[15:0] instruction = pc_is_mis ? {m1OutputInstruction[7:0],fetchOutputInstruction[15:8]} :fetchOutputInstruction;

    //Decode Logic 
    //Decompose the Instruction
    wire [3:0] de_opcode = instruction[15:12];
    wire [3:0] de_ra = instruction[11:8];
    wire [3:0] de_rb = instruction[7:4];
    wire [3:0] de_rt = instruction[3:0];
    wire [7:0] de_i = instruction[11:4];

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
    
    //Ensure the instruction is valid
    wire de_is_invalid = ~(de_is_sub|de_is_movl|de_is_movh|de_is_jz|de_is_jnz|de_is_js|de_is_jns|de_is_ld|de_is_st);

    //Feed into register ports

    wire [3:0] r2 = de_is_sub ? de_rb : de_rt;
    
    assign raddr0_ = de_ra;
    assign raddr1_ = r2;

    //Decode Stage, copies the information into registers

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



    //Memory Phase, copies the information into registers
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

    // Forwarding logic, first if avaliable forwards from the M stage then the E stage, 
    // if no forwarding and not r0, take the value from the register file
    wire [15:0] mem_rdata1 = r_forwardfromM==d_r2 ?v_forwardfromM : r_forwardfromE == d_r2 ? v_forwardfromE : d_r2==4'b0000 ? 0: rdata1;
    wire [15:0] mem_rdata0 = r_forwardfromM==d_ra ? v_forwardfromM : r_forwardfromE == d_ra ? v_forwardfromE : d_ra==4'b0000 ? 0 : rdata0;

    //if PC is misaligned use the other read port on memory
    assign m0InputInstruction = pc_is_mis ? pc+2  : mem_rdata0[15:0];


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
    //Wires used for forwarding from E stage
    wire [15:0]c_rdata0 = r_forwardfromE == m_ra ? v_forwardfromE : m_rdata0;
    wire [15:0]c_rdata1 = r_forwardfromE == m_r2 ? v_forwardfromE : m_rdata1;

    //Computes a value which can be forwarded to the mem_ wires
    wire [15:0]m_computed_value = m_is_sub ? m_rdata0 - m_rdata1:
    m_is_movl ? {{8{m_i[7]}}, m_i} :
    m_is_movh ? {m_i,c_rdata1[7:0]} :
    m_is_jz ? c_rdata0 == 0 :
    m_is_jnz ? c_rdata0 != 0 :
    m_is_js ? c_rdata0[15] == 1 :
    m_is_jns ? c_rdata0[15] == 0 :
    m_is_st ? c_rdata1 : 0;

    //Determines if it can and what it should forward from the M stage
    wire forwardfromM = (~(m_is_jmp|m_is_st)&validM) && (m_rt!=4'b0000) ? 1:0;
    wire[3:0] r_forwardfromM = forwardfromM ? m_rt : 4'b0000;
    wire[15:0] v_forwardfromM = forwardfromM ? m_computed_value : 16'h0000;

    
    //Execute stage

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

    reg is_str_ld;
    reg [15:0]str_ld_val;

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
        e_rdata1 <= c_rdata1;
        e_rdata0 <= c_rdata0;
        e_rt <= m_rt;
        e_ra <= m_ra;
        e_rb <= m_rb; 

        //Handles the memory forwarding needed if there is a store then a load instruction
        is_str_ld <= (e_rdata0 == m_rdata0) & validE & validM & e_is_st & m_is_ld;
        str_ld_val <= e_rdata1;

        //Writes to console if the target is r0
        if(e_rt==4'b0000 &&  ~(e_is_jmp|e_is_st) &&validE &&!e_is_invalid)
           $write("%c",e_output[7:0]);    

    end
    
    //Computes a value for the e stage which is used when writing to memory
    wire [15:0]e_computed_value = e_is_sub ? e_rdata0 - e_rdata1:
    e_is_movl ? {{8{e_i[7]}}, e_i} :
    e_is_movh ? {e_i,e_rdata1[7:0]} :
    e_is_jz ? e_rdata0 == 0 :
    e_is_jnz ? e_rdata0 != 0 :
    e_is_js ? e_rdata0[15] == 1 :
    e_is_jns ? e_rdata0[15] == 0 :
    e_is_st ? e_rdata1 : 0;


    //Checks if writeback should use computed value, or a value from memory/forwarded value from store_load
    wire[15:0] e_output = (is_str_ld) ? str_ld_val:
                             e_is_ld ? m1OutputInstruction 
                             : e_computed_value;


    //Forwarding wires from E
    wire forwardfromE = regWen && (e_rt!=4'b0000) ? 1:0;
    wire[3:0] r_forwardfromE = forwardfromE ? e_rt : 4'b0000;
    wire[15:0] v_forwardfromE = forwardfromE ? e_output : 16'h0000;



    
    //Flush Conditions
    wire is_ld_ld = validE & validM & e_is_ld & m_is_ld;
    wire is_self_modifying = memWen & e_rdata0<=pc & e_rdata0>=e_pc;
    assign flush = (is_self_modifying)|(is_ld_ld)|(validE & e_is_jmp & e_computed_value  == 1 ) | (e_is_invalid & validE)  ? 1 : 0;
    wire[15:0] flushTarget = is_ld_ld|is_self_modifying ? e_pc+2 : flush ? e_rdata1 : pc + 2;

    //Write to memory
    assign memWen = e_is_st & validE;
    assign memWaddr = e_rdata0[15:1];
    assign memWdata = e_computed_value;

    //Write to registers
    assign regWen = ~(e_is_jmp|e_is_st)&validE;
    assign regWaddr = e_rt;
    assign regWdata = e_output;

    //Checks halt condition
    always @(posedge clk) begin
        if (e_is_invalid & validE) begin
            halt <= 1;
        end
    end

endmodule
