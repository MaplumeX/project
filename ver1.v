module ver1 (
        // 输入端口
        input wire [2:0] SWC_SWB_SWA,      // 模式选择信号
        input wire [3:0] IR7_IR4,          // 指令寄存器高 4 位
        input wire CLR,                    // 复位信号，低电平有效
        input wire T3,                     // 时序信号 T3，用于更新状态
        input wire W1, W2, W3,             // 微指令节拍信号
        input wire C, Z,                   // 状态标志：进位标志 C、零标志 Z
        // 输出端口
        output reg SELCTL,                 // 选择控制信号
        output reg ABUS,                   // 控制 ALU 输出送总线
        output reg SBUS,                   // 控制开关输入送总线
        output reg MBUS,                   // 控制存储器输出送总线
        output reg M,CIN,                  // M 控制 ALU 运算类型，CIN 为进位输入
        output reg DRW,                    // 寄存器写控制信号
        output reg LDZ,                    // 零标志写控制信号
        output reg LDC,                    // 进位标志写控制信号
        output reg MEMW,                   // 存储器写控制信号
        output reg ARINC,                  // 地址寄存器 AR 加 1 控制信号
        output reg PCINC,                  // 程序计数器 PC 加 1 控制信号
        output reg PCADD,                  // PC 相对寻址加法控制信号
        output reg LPC,                    // PC 装载控制信号
        output reg LAR,                    // AR 装载控制信号
        output reg LIR,                    // IR 装载控制信号
        output reg STOP,                   // 停机/暂停控制信号
        output reg SHORT,                  // 短周期控制信号
        output reg LONG,                   // 长周期控制信号
        output reg [3:0] S, SEL            // S 为 ALU 功能选择，SEL 为寄存器选择
    );
    // 状态标志
    reg ST0;
    wire SST0;
    // 工作模式状态
    reg [2:0] Q; 
    wire WRITE_REG;
    wire READ_REG;
    wire INS_FETCH;
    wire READ_MEM;
    wire WRITE_MEM;

    // 原有指令译码
    wire NOP;
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
    // 新增指令译码
    wire OUT;
    wire MOV;
    wire CMP;
    wire NOT;
    wire DEC;

	always @(negedge T3)
	begin 
			case  (SWC_SWB_SWA)
				3'b100:  Q=3'b100;
				3'b011:  Q=3'b011;
				3'b000:  Q=3'b000;
				3'b010:  Q=3'b010;
				3'b001:  Q=3'b001;
			    default:
			             Q=3'b111; 
			 endcase 
			     
	end			
    assign WRITE_REG = (Q == 3'b100) ? 1: 0;
    assign READ_REG = (Q == 3'b011) ? 1: 0; // 读寄存器模式
    assign INS_FETCH = (Q == 3'b000) ? 1: 0; // 取指模式
    assign READ_MEM = (Q == 3'b010) ? 1: 0; // 读存储器模式
    assign WRITE_MEM = (Q == 3'b001) ? 1: 0; // 写存储器模式


    assign NOP = (IR7_IR4 == 4'b0000 && INS_FETCH == 1 && ST0 == 1) ? 1: 0;
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
        else if (SST0) begin // ST0 为 0 且满足置位条件时置 1
            ST0 <= 1'b1;
        end
        else if(ST0 && W2 && WRITE_REG)begin
    ST0 <=1'b0;
    end
        // 注意：ST0 主要由 CLR 复位，由 SST0 置位。
        // 如需在其他条件下从 1 回到 0，需要补充相应逻辑。
        // 当前保留原有状态转换方式。
    end
    assign SST0 = (ST0 == 1'b0) && (
               (SWC_SWB_SWA == 3'b100 && W2) || // 写寄存器模式，W2 有效
               (SWC_SWB_SWA == 3'b010 && W1) || // 读存储器模式，W1 有效
               (SWC_SWB_SWA == 3'b001 && W1) || // 写存储器模式，W1 有效
               (SWC_SWB_SWA == 3'b000 && W2)
           );

    always @(*) begin
        SELCTL = 1'b0;
        ABUS = 1'b0;
        SBUS = 1'b0;
        MBUS = 1'b0;
        M = 1'b0;
        CIN = 1'b0;
        DRW = 1'b0;
        LDZ = 1'b0;
        LDC = 1'b0;
        MEMW = 1'b0;
        ARINC = 1'b0;
        PCINC = 1'b0;
        PCADD = 1'b0;
        LPC = 1'b0;
        LAR = 1'b0;
        LIR = 1'b0;
        STOP = 1'b0;
        SHORT = 1'b0;
        LONG = 1'b0;
        S = 4'b0000;
        SEL = 4'b0000;

        case (1'b1)
            WRITE_REG: begin
                if (W1) begin
                    SBUS = 1'b1;
                    SELCTL = 1'b1;
                    DRW = 1'b1;
                    STOP = 1'b1;
                    SEL[0] = 1'b1;
                    SEL[1] = !ST0;
                    SEL[3] = ST0;
                end
                if (W2) begin
                    SBUS = 1'b1;
                    SELCTL = 1'b1;
                    DRW = 1'b1;
                    STOP = 1'b1;
                    SEL[1] = ST0;
                    SEL[2] = 1'b1;
                    SEL[3] = ST0;
                end
            end
            READ_REG: begin
                if (W1) begin
                    SELCTL = 1'b1;
                    STOP = 1'b1;
                    SEL[0] = 1'b1;
                end
                if (W2) begin
                    SELCTL = 1'b1;
                    STOP = 1'b1;
                    SEL[0] = 1'b1;
                    SEL[1] = 1'b1;
                    SEL[3] = 1'b1;
                end
            end
            READ_MEM: begin
                if (W1) begin
                    SBUS = !ST0;
                    SELCTL = 1'b1;
                    STOP = 1'b1;
                    LAR = !ST0;
                    SHORT = 1'b1;
                    MBUS = ST0;
                    ARINC = ST0;
                end
            end
            WRITE_MEM: begin
                if (W1) begin
                    SBUS = 1'b1;
                    SELCTL = 1'b1;
                    STOP = 1'b1;
                    LAR = !ST0;
                    SHORT = 1'b1;
                    ARINC = ST0;
                    MEMW = ST0;
                end
            end
            INS_FETCH: begin
                if (!ST0) begin
                    if (W1) begin
                        STOP = 1'b1;
                    end
                    if (W2) begin
                        SBUS = 1'b1;
                        LPC = 1'b1;
                    end
                end
                else begin
                    case (IR7_IR4)
                        4'b0000: begin
                            if (W1) begin
                                SHORT = 1'b1;
                                PCINC = 1'b1;
                                LIR = 1'b1;
                            end
                        end
                        4'b0001: begin
                            if (W1) begin
                                DRW = 1'b1;
                                SHORT = 1'b1;
                                PCINC = 1'b1;
                                LIR = 1'b1;
                                CIN = 1'b1;
                                ABUS = 1'b1;
                                LDZ = 1'b1;
                                S[3] = 1'b1;
                                S[0] = 1'b1;
                            end
                        end
                        4'b0010: begin
                            if (W1) begin
                                DRW = 1'b1;
                                SHORT = 1'b1;
                                PCINC = 1'b1;
                                LIR = 1'b1;
                                ABUS = 1'b1;
                                LDZ = 1'b1;
                                LDC = 1'b1;
                                S[2] = 1'b1;
                                S[1] = 1'b1;
                            end
                        end
                        4'b0011: begin
                            if (W1) begin
                                DRW = 1'b1;
                                SHORT = 1'b1;
                                PCINC = 1'b1;
                                LIR = 1'b1;
                                ABUS = 1'b1;
                                LDZ = 1'b1;
                                M = 1'b1;
                                S[3] = 1'b1;
                                S[1] = 1'b1;
                                S[0] = 1'b1;
                            end
                        end
                        4'b0100: begin
                            if (W1) begin
                                DRW = 1'b1;
                                SHORT = 1'b1;
                                PCINC = 1'b1;
                                LIR = 1'b1;
                                ABUS = 1'b1;
                                LDZ = 1'b1;
                                LDC = 1'b1;
                            end
                        end
                        4'b0101: begin
                            if (W1) begin
                                LAR = 1'b1;
                                ABUS = 1'b1;
                                M = 1'b1;
                                S[3] = 1'b1;
                                S[1] = 1'b1;
                                LONG = 1'b1;
                            end
                            if (W2) begin
                                DRW = 1'b1;
                                MBUS = 1'b1;
                                PCINC = 1'b1;
                                LIR = 1'b1;
                            end
                        end
                        4'b0110: begin
                            if (W1) begin
                                LAR = 1'b1;
                                ABUS = 1'b1;
                                M = 1'b1;
                                S = 4'b1111;
                                LONG = 1'b1;
                            end
                            if (W2) begin
                                MEMW = 1'b1;
                                ABUS = 1'b1;
                                M = 1'b1;
                                S[3] = 1'b1;
                                S[1] = 1'b1;
                                PCINC = 1'b1;
                                LIR = 1'b1;
                            end
                        end
                        4'b0111: begin
                            if (W1) begin
                                if (!C) begin
                                    SHORT = 1'b1;
                                    PCINC = 1'b1;
                                    LIR = 1'b1;
                                end
                                else begin
                                    LONG = 1'b1;
                                    PCADD = 1'b1;
                                end
                            end
                            if (W2 && C) begin
                                PCINC = 1'b1;
                                LIR = 1'b1;
                            end
                        end
                        4'b1000: begin
                            if (W1) begin
                                if (!Z) begin
                                    SHORT = 1'b1;
                                    PCINC = 1'b1;
                                    LIR = 1'b1;
                                end
                                else begin
                                    LONG = 1'b1;
                                    PCADD = 1'b1;
                                end
                            end
                            if (W2 && Z) begin
                                PCINC = 1'b1;
                                LIR = 1'b1;
                            end
                        end
                        4'b1001: begin
                            if (W1) begin
                                LPC = 1'b1;
                                ABUS = 1'b1;
                                M = 1'b1;
                                S[3] = 1'b1;
                                S[2] = 1'b1;
                                S[1] = 1'b1;
                                LONG = 1'b1;
                            end
                            if (W2) begin
                                PCINC = 1'b1;
                                LIR = 1'b1;
                            end
                        end
                        4'b1010: begin
                            if (W1) begin
                                PCINC = 1'b1;
                                LIR = 1'b1;
                            end
                            if (W2) begin
                                ABUS = 1'b1;
                                M = 1'b1;
                                S[3] = 1'b1;
                                S[1] = 1'b1;
                            end
                        end
                        4'b1011: begin
                            if (W1) begin
                                PCINC = 1'b1;
                                LIR = 1'b1;
                            end
                            if (W2) begin
                                DRW = 1'b1;
                                ABUS = 1'b1;
                                M = 1'b1;
                                S[3] = 1'b1;
                                S[1] = 1'b1;
                            end
                        end
                        4'b1100: begin
                            if (W1) begin
                                PCINC = 1'b1;
                                LIR = 1'b1;
                            end
                            if (W2) begin
                                ABUS = 1'b1;
                                LDZ = 1'b1;
                                LDC = 1'b1;
                                S[2] = 1'b1;
                                S[1] = 1'b1;
                            end
                        end
                        4'b1101: begin
                            if (W1) begin
                                PCINC = 1'b1;
                                LIR = 1'b1;
                            end
                            if (W2) begin
                                DRW = 1'b1;
                                ABUS = 1'b1;
                                LDC = 1'b1;
                                M = 1'b1;
                            end
                        end
                        4'b1110: begin
                            if (W1) begin
                                STOP = 1'b1;
                            end
                        end
                        4'b1111: begin
                            if (W1) begin
                                PCINC = 1'b1;
                                LIR = 1'b1;
                            end
                            if (W2) begin
                                DRW = 1'b1;
                                CIN = 1'b1;
                                ABUS = 1'b1;
                                LDZ = 1'b1;
                                LDC = 1'b1;
                                S = 4'b1111;
                            end
                        end
                    endcase
                end
            end
        endcase
    end

endmodule

