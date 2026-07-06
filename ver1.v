module ver1 (
        //输入端口
        input wire [2:0] SWC_SWB_SWA,      // 模式选择信号
        input wire [3:0] IR7_IR4,          // 指令寄存器高4位
        input wire CLR,                    // 复位信号 (低有效)
        input wire T3,                     // 时序信号 T3 (作为ST0的时钟)
        input wire W1, W2, W3,             // 微指令时序信号
        input wire C, Z,                   // 状态标志：进位C，零Z
        //输出端口
        output wire SELCTL,                 // 选择控制信号
        output wire ABUS,                   // 控制ALU数据是否进入数据总线
        output wire SBUS,                   // 控制手动输入数据是否进入数据总线
        output wire MBUS,                   // 控制双端口存储器的数据送到数据总线
        output wire M,CIN,                  // M是控制ALU是逻辑运算还是算数运算 CIN用于区分S码和M对应的操作是有进位操作或是无进位操作
        output wire DRW,                    // 控制寄存器写入信号
        output wire LDZ,                    // 若为1，当运算结果为0时设Z为1，若不为0则设Z为0
        output wire LDC,                    // 若为1，当运算结果产生进位时设C为1，若无进位则设C为0
        output wire MEMW,                   // 控制存储器双端口RAM写入信号，为1时将总线中的值写入储存器
        output wire ARINC,                  // 控制地址寄存器AR的值加1信号
        output wire PCINC,                  // 控制地址寄存器PC的值加1信号
        output wire PCADD,                  // 控制PC加指令地址信号
        output wire LPC,                    // 控制将数据总线上数据写入PC寄存器
        output wire LAR,                    // 控制将数据总线上数据写入AR寄存器
        output wire LIR,                    // 控制将数据总线上数据写入IR寄存器
        output wire STOP,                   // 停止信号
        output wire SHORT,                  // 短延时信号
        output wire LONG,                   // 长延时信号
        output wire [3:0] S, SEL            // S控制ALU产生不同的函数 SEL用于 2 - 4 译码器
    );
    //状态标识
    reg ST0;
    wire SST0;
    //五种基本状态
    reg [2:0] Q; 
    wire WRITE_REG;
    wire READ_REG;
    wire INS_FETCH;
    wire READ_MEM;
    wire WRITE_MEM;

    //原本的指令译码
    wire ADD;
    wire SUB;
    wire AND;
    wire INC;
    wire LD;
    wire ST;
    wire JC;
    wire JZ;
    wire JMP;
    wire STP;
    //增加的指令
    wire OUT;
    wire MOV;
    wire CMP;
    wire NOT;
    wire DEC;

	always @(negedge T3)
	begin 
			case  (SWC_SWB_SWA)
				3'b100:  Q=100;
				3'b011:  Q=011;
				3'b000:  Q=000;
				3'b010:  Q=010;
				3'b001:  Q=001;
			    default:
			             Q=111; 
			 endcase 
			     
	end			
    assign WRITE_REG = (Q == 3'b100) ? 1: 0;
    assign READ_REG = (Q == 3'b011) ? 1: 0; // 读取寄存器模式
    assign INS_FETCH = (Q == 3'b000) ? 1: 0; // 指令取指模式
    assign READ_MEM = (Q == 3'b010) ? 1: 0; // 读取存储器模式
    assign WRITE_MEM = (Q == 3'b001) ? 1: 0; // 写入存储器模式


    assign ADD = (IR7_IR4 == 4'b0001 && INS_FETCH == 1 && ST0 == 1) ? 1: 0;
    assign SUB = (IR7_IR4 == 4'b0010 && INS_FETCH == 1 && ST0 == 1) ? 1: 0;
    assign AND = (IR7_IR4 == 4'b0011 && INS_FETCH == 1 && ST0 == 1) ? 1: 0;
    assign INC = (IR7_IR4 == 4'b0100 && INS_FETCH == 1 && ST0 == 1) ? 1: 0;
    assign LD = (IR7_IR4 == 4'b0101 && INS_FETCH == 1 && ST0 == 1) ? 1: 0;
    assign ST = (IR7_IR4 == 4'b0110 && INS_FETCH == 1 && ST0 == 1) ? 1: 0;
    assign JC = (IR7_IR4 == 4'b0111 && INS_FETCH == 1 && ST0 == 1) ? 1: 0;
    assign JZ = (IR7_IR4 == 4'b1000 && INS_FETCH == 1 && ST0 == 1) ? 1: 0;
    assign JMP = (IR7_IR4 == 4'b1001 && INS_FETCH == 1 && ST0 == 1) ? 1: 0;
    assign STP = (IR7_IR4 == 4'b1110 && INS_FETCH == 1 && ST0 == 1) ? 1: 0;

    assign OUT = (IR7_IR4 == 4'b1010 && INS_FETCH == 1 && ST0 == 1) ? 1: 0;
    assign MOV = (IR7_IR4 == 4'b1011 && INS_FETCH == 1 && ST0 == 1) ? 1: 0;
    assign CMP = (IR7_IR4 == 4'b1100 && INS_FETCH == 1 && ST0 == 1) ? 1: 0;
    assign NOT = (IR7_IR4 == 4'b1101 && INS_FETCH == 1 && ST0 == 1) ? 1: 0;
    assign DEC = (IR7_IR4 == 4'b1111 && INS_FETCH == 1 && ST0 == 1) ? 1: 0;


    always @(negedge T3 or negedge CLR) begin
        if (CLR == 0 ) begin
            ST0 <= 1'b0;
        end
        else if (SST0) begin // st0_set_condition 在 ST0=0 且特定条件满足时为真
            ST0 <= 1'b1;
        end
        else if(ST0 && W2 && WRITE_REG)begin
    ST0 <=1'b0;
    end
        // 注意: ST0 不会自动从1翻转回0，除非被CLR复位。
        // 如果需要ST0在某些条件下从1回到0，需要额外的逻辑。
        // 根据原始代码，ST0 从0到1后就保持。
    end
    assign SST0 = (ST0 == 1'b0) && (
               (SWC_SWB_SWA == 3'b100 && W2) || // 写寄存器模式，W2有效
               (SWC_SWB_SWA == 3'b010 && W1) || // 读存储器模式，W1有效
               (SWC_SWB_SWA == 3'b001 && W1) || // 写存储器模式，W1有效
               (SWC_SWB_SWA == 3'b000 && W2)
           );

    assign SBUS = ((WRITE_REG ||(READ_MEM && !ST0) || WRITE_MEM ) && W1) || (WRITE_REG && W2) ||((INS_FETCH && !ST0) && W2);
    assign SEL[3] = ((WRITE_REG && (W1 || W2)) && ST0) || (READ_REG && W2);
    assign SEL[2] = WRITE_REG && W2;
    assign SEL[1] = (WRITE_REG && ((W1 && !ST0) || (W2 && ST0))) || (READ_REG && W2);
    assign SEL[0] = (WRITE_REG && W1) || (READ_REG && (W1 || W2));
    assign SELCTL = ((WRITE_REG || READ_REG) && (W1 || W2)) || ((READ_MEM || WRITE_MEM) && W1);
    assign DRW = (WRITE_REG && (W1 || W2)) || ((ADD || SUB || AND || INC || NOT || MOV || DEC) && W2) || (LD && W3);
    assign STOP = ((WRITE_REG || READ_REG) && (W1 || W2)) || ((READ_MEM || WRITE_MEM) && W1) || (STP && W2) || (INS_FETCH && !ST0 && W1);
    assign LAR = ((READ_MEM || WRITE_MEM) && W1 && !ST0)||((ST || LD) && W2);
    assign SHORT = ((READ_MEM || WRITE_MEM) && W1);
    assign MBUS = (READ_MEM && W1 && ST0) || (LD && W3);
    assign ARINC = (WRITE_MEM || READ_MEM) && W1 && ST0;
    assign MEMW = (WRITE_MEM && W1 && ST0) || (ST && W3);
    assign PCINC = INS_FETCH && ST0 && W1;
    assign LIR = INS_FETCH && ST0 && W1;
    assign CIN = (ADD || DEC) && W2;
    assign ABUS = ((ADD || SUB || AND || INC || LD || ST || JMP || DEC) && W2) || (ST && W3) || ((MOV || OUT) && W2) || (CMP && W2) || (NOT && W2);
    assign LDZ = (ADD || SUB || AND || INC || CMP || DEC) && W2;
    assign LDC = (ADD || SUB || INC || CMP || NOT || DEC) && W2;
    assign M = ((AND || LD || ST || JMP) && W2) || (ST && W3) || ((NOT || MOV || OUT) && W2);
    assign S[3] = ((ADD || AND || LD || ST || JMP || OUT || MOV || DEC) && W2) || (ST && W3) ;
    assign S[2] = ((SUB || ST || JMP || CMP || DEC) && W2);
    assign S[1] = ((SUB || AND || LD || ST || JMP || OUT || CMP || MOV || DEC) && W2) || (ST && W3);
    assign S[0] = (ADD || AND || ST || JMP || DEC) && W2;
    assign LPC  = (JMP && W2) || (INS_FETCH && !ST0 && W2);
    assign LONG = (ST || LD) && W2;
    assign PCADD = ((C && JC) || (Z && JZ)) && W2;

endmodule

