// TEC-8 硬布线控制器
//
// 本模块根据面板模式开关 SWC_SWB_SWA、时序节拍 W1/W2、指令寄存器高 4 位
// IR7_IR4 以及标志位 C/Z，组合产生各类数据通路控制信号。整体逻辑可分为：
// 1. 模式锁存：在 T3 下降沿采样当前工作模式；
// 2. ST0 状态位：区分手动操作或取指流程中的前后阶段；
// 3. 控制信号译码：根据模式、指令和节拍输出具体微操作控制信号。
module pipelined_hardwired_controller (
        // 输入端口
        input wire [2:0] SWC_SWB_SWA,      // 模式选择信号
        input wire [3:0] IR7_IR4,          // 指令寄存器高 4 位
        input wire CLR,                    // 复位信号，低电平有效
        input wire T3,                     // 时序信号 T3，用于更新状态
        input wire W1, W2,                 // 微指令节拍信号
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
        output reg [3:0] S, SEL            // S 为 ALU 功能选择，SEL 为寄存器选择
    );
    // ST0 是控制器内部阶段标志：
    // ST0=0 表示初始/装载阶段，ST0=1 表示已经进入后续执行阶段。
    reg ST0;
    wire SST0;
    // Q 在 T3 下降沿锁存当前面板工作模式，避免组合开关抖动直接影响控制输出。
    reg [2:0] Q; 
    wire WRITE_REG;
    wire READ_REG;
    wire INS_FETCH;
    wire READ_MEM;
    wire WRITE_MEM;

    // 指令译码线。
    // 这些信号把 IR7_IR4 翻译成语义化的指令名，便于观察和后续扩展；
    // 当前主控制输出仍直接在 case (IR7_IR4) 中按编码生成。
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

	// 在每个 T3 下降沿采样模式开关，将有效模式写入 Q。
	// 未定义的开关组合统一归入 3'b111，后续不会命中任何工作模式。
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
    // 工作模式译码：每个信号对应流程图中的一个入口分支。
    assign WRITE_REG = (Q == 3'b100) ? 1: 0;
    assign READ_REG = (Q == 3'b011) ? 1: 0; // 读寄存器模式
    assign INS_FETCH = (Q == 3'b000) ? 1: 0; // 取指模式
    assign READ_MEM = (Q == 3'b010) ? 1: 0; // 读存储器模式
    assign WRITE_MEM = (Q == 3'b001) ? 1: 0; // 写存储器模式


    // 指令译码只在取指/执行模式且 ST0=1 时有效，避免手动模式误触发指令控制。
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


    // ST0 状态更新逻辑：
    // 1. CLR 低电平复位时回到初始阶段；
    // 2. SST0 有效时从第一阶段进入第二阶段；
    // 3. 写寄存器模式完成第二个节拍后回到第一阶段，便于继续手动写入。
    always @(negedge T3 or negedge CLR) begin
        if (CLR == 0 ) begin
            ST0 <= 1'b0;
        end
        else if (SST0) begin // ST0 为 0 且满足置位条件时置 1
            ST0 <= 1'b1;
        end
        else if(ST0 && W2 && WRITE_REG)begin
            ST0 <= 1'b0;
        end
        // 注意：除写寄存器模式外，ST0 主要由 CLR 复位，由 SST0 置位。
        // 如需在其他模式下从 1 回到 0，需要补充相应逻辑。
        // 当前保留原有状态转换方式。
    end
    // SST0 是 ST0 的置位条件。
    // 不同模式进入第二阶段所需的节拍不同：写寄存器使用 W2，读/写存储器和取指使用 W1。
    assign SST0 = (ST0 == 1'b0) && (
               (SWC_SWB_SWA == 3'b100 && W2) || // 写寄存器模式，W2 有效
               (SWC_SWB_SWA == 3'b010 && W1) || // 读存储器模式，W1 有效
               (SWC_SWB_SWA == 3'b001 && W1) || // 写存储器模式，W1 有效
               (SWC_SWB_SWA == 3'b000 && W1)
           );

    // 主控制组合逻辑。
    // 先给全部输出默认清零，随后只在命中的模式、指令和节拍中拉高需要的控制信号，
    // 这样可以避免组合逻辑推断出锁存器。
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
        S = 4'b0000;
        SEL = 4'b0000;

        case (1'b1)
            WRITE_REG: begin // 手动写寄存器：通过 SBUS 将开关数据写入指定寄存器。
                if (W1) begin // 第一个写入节拍，根据 ST0 选择低位或高位寄存器组。
                    SBUS = 1'b1;
                    SELCTL = 1'b1;
                    DRW = 1'b1;
                    STOP = 1'b1;
                    SEL[0] = 1'b1;
                    SEL[1] = !ST0;
                    SEL[3] = ST0;
                end
                if (W2) begin // 第二个写入节拍，继续选择目标寄存器并写入开关数据。
                    SBUS = 1'b1;
                    SELCTL = 1'b1;
                    DRW = 1'b1;
                    STOP = 1'b1;
                    SEL[1] = ST0;
                    SEL[2] = 1'b1;
                    SEL[3] = ST0;
                end
            end
            READ_REG: begin // 手动读寄存器：只选择寄存器输出，不写入数据通路。
                if (W1) begin // 第一个读节拍，选择一组寄存器输出。
                    SELCTL = 1'b1;
                    STOP = 1'b1;
                    SEL[0] = 1'b1;
                end
                if (W2) begin // 第二个读节拍，切换 SEL 组合读取另一组寄存器。
                    SELCTL = 1'b1;
                    STOP = 1'b1;
                    SEL[0] = 1'b1;
                    SEL[1] = 1'b1;
                    SEL[3] = 1'b1;
                end
            end
            READ_MEM: begin // 手动读存储器：ST0=0 装载地址，ST0=1 读出数据并递增 AR。
                if (W1) begin // 同一节拍内由 ST0 区分“装载地址”和“读数据”。
                    SBUS = !ST0;
                    SELCTL = 1'b1;
                    STOP = 1'b1;
                    LAR = !ST0;
                    SHORT = 1'b1;
                    MBUS = ST0;
                    ARINC = ST0;
                end
            end
            WRITE_MEM: begin // 手动写存储器：ST0=0 装载地址，ST0=1 写入数据并递增 AR。
                if (W1) begin // 同一节拍内由 ST0 区分“装载地址”和“写数据”。
                    SBUS = 1'b1;
                    SELCTL = 1'b1;
                    STOP = 1'b1;
                    LAR = !ST0;
                    SHORT = 1'b1;
                    ARINC = ST0;
                    MEMW = ST0;
                end
            end
            INS_FETCH: begin // 取指/执行模式：ST0=0 初始化 PC，ST0=1 根据 IR7_IR4 执行指令。
                if (!ST0) begin
                    if (W1) begin // 将开关输入经 SBUS 装入 PC，并在本拍请求进入取指阶段。
                        SBUS = 1'b1;
                        LPC = 1'b1;
                        STOP = 1'b1;
                    end
                    if (W2) begin // 修改 PC 后取第一条指令，并使 PC 指向下一条。
                        LIR = 1'b1;
                        PCINC = 1'b1;
                    end
                end
                else begin
                    // 指令微操作译码：短指令通常在 W1 完成，访存/跳转等长指令分 W1、W2 完成。
                    case (IR7_IR4)
                        4'b0000: begin // NOP：空操作，只完成取下一条指令。
                            if (W1) begin // 短周期：PC 加 1，并把下一条指令装入 IR。
                                SHORT = 1'b1;
                                PCINC = 1'b1;
                                LIR = 1'b1;
                            end
                        end
                        4'b0001: begin // ADD：执行加法，结果写回寄存器并更新 Z 标志。
                            if (W1) begin // 短周期：ALU 加法结果经 ABUS 写回，同时取下一条指令。
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
                        4'b0010: begin // SUB：执行减法，结果写回寄存器并更新 Z/C 标志。
                            if (W1) begin // 短周期：ALU 减法结果经 ABUS 写回，同时取下一条指令。
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
                        4'b0011: begin // AND：执行按位与，结果写回寄存器并更新 Z 标志。
                            if (W1) begin // 短周期：逻辑运算结果经 ABUS 写回，同时取下一条指令。
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
                        4'b0100: begin // INC：执行自增，结果写回寄存器并更新 Z/C 标志。
                            if (W1) begin // 短周期：ALU 自增结果经 ABUS 写回，同时取下一条指令。
                                DRW = 1'b1;
                                SHORT = 1'b1;
                                PCINC = 1'b1;
                                LIR = 1'b1;
                                ABUS = 1'b1;
                                LDZ = 1'b1;
                                LDC = 1'b1;
                            end
                        end
                        4'b0101: begin // LD：先形成访存地址，再从存储器读数写回寄存器。
                            if (W1) begin // 长周期第 1 拍：ALU 输出有效地址，经 ABUS 装入 AR。
                                LAR = 1'b1;
                                ABUS = 1'b1;
                                M = 1'b1;
                                S[3] = 1'b1;
                                S[1] = 1'b1;
                            end
                            if (W2) begin // 长周期第 2 拍：存储器数据经 MBUS 写回寄存器，并取下一条指令。
                                DRW = 1'b1;
                                MBUS = 1'b1;
                                PCINC = 1'b1;
                                LIR = 1'b1;
                            end
                        end
                        4'b0110: begin // ST：先形成访存地址，再将寄存器数据写入存储器。
                            if (W1) begin // 长周期第 1 拍：ALU 输出有效地址，经 ABUS 装入 AR。
                                LAR = 1'b1;
                                ABUS = 1'b1;
                                M = 1'b1;
                                S = 4'b1111;
                            end
                            if (W2) begin // 长周期第 2 拍：寄存器数据经 ABUS 写入存储器，并取下一条指令。
                                MEMW = 1'b1;
                                ABUS = 1'b1;
                                M = 1'b1;
                                S[3] = 1'b1;
                                S[1] = 1'b1;
                                PCINC = 1'b1;
                                LIR = 1'b1;
                            end
                        end
                        4'b0111: begin // JC：C=1 时执行 PC 相对跳转，否则顺序取下一条指令。
                            if (W1) begin // 第 1 拍判断 C：不跳转走短周期，跳转则启动 PCADD 长周期。
                                if (!C) begin
                                    SHORT = 1'b1;
                                    PCINC = 1'b1;
                                    LIR = 1'b1;
                                end
                                else begin
                                    PCADD = 1'b1;
                                end
                            end
                            if (W2 && C) begin // 条件满足后的第 2 拍：跳转后继续取下一条指令。
                                PCINC = 1'b1;
                                LIR = 1'b1;
                            end
                        end
                        4'b1000: begin // JZ：Z=1 时执行 PC 相对跳转，否则顺序取下一条指令。
                            if (W1) begin // 第 1 拍判断 Z：不跳转走短周期，跳转则启动 PCADD 长周期。
                                if (!Z) begin
                                    SHORT = 1'b1;
                                    PCINC = 1'b1;
                                    LIR = 1'b1;
                                end
                                else begin
                                    PCADD = 1'b1;
                                end
                            end
                            if (W2 && Z) begin // 条件满足后的第 2 拍：跳转后继续取下一条指令。
                                PCINC = 1'b1;
                                LIR = 1'b1;
                            end
                        end
                        4'b1001: begin // JMP：无条件跳转，将目标地址装入 PC。
                            if (W1) begin // 长周期第 1 拍：ALU 输出跳转地址，经 ABUS 装入 PC。
                                LPC = 1'b1;
                                ABUS = 1'b1;
                                M = 1'b1;
                                S = 4'b1111;
                            end
                            if (W2) begin // 长周期第 2 拍：跳转后继续取下一条指令。
                                PCINC = 1'b1;
                                LIR = 1'b1;
                            end
                        end
                        4'b1010: begin // OUT：将源寄存器内容经 ALU/ABUS 输出到外部总线。
                            if (W1) begin // 长周期第 1 拍：把源寄存器内容经 ALU 送到 ABUS。
                                ABUS = 1'b1;
                                M = 1'b1;
                                S = 4'b1010;
                            end
                            if (W2) begin // 长周期第 2 拍：取下一条指令。
                                PCINC = 1'b1;
                                LIR = 1'b1;
                            end
                        end
                        4'b1011: begin // MOV：源寄存器经 ABUS 写回目的寄存器。
                            if (W1) begin // 长周期第 1 拍：把源寄存器内容经 ABUS 写入目的寄存器。
                                DRW = 1'b1;
                                ABUS = 1'b1;
                                M = 1'b1;
                                S = 4'b1010;
                            end
                            if (W2) begin // 长周期第 2 拍：取下一条指令。
                                PCINC = 1'b1;
                                LIR = 1'b1;
                            end
                        end
                        4'b1100: begin // CMP：执行减法比较，只更新 Z/C，不写回寄存器。
                            if (W1) begin // 长周期第 1 拍：执行减法比较，只锁存标志位。
                                ABUS = 1'b1;
                                LDZ = 1'b1;
                                LDC = 1'b1;
                                S = 4'b0110;
                            end
                            if (W2) begin // 长周期第 2 拍：取下一条指令。
                                PCINC = 1'b1;
                                LIR = 1'b1;
                            end
                        end
                        4'b1101: begin // NOT：执行按位取反并写回寄存器。
                            if (W1) begin // 长周期第 1 拍：执行取反，结果经 ABUS 写回寄存器。
                                DRW = 1'b1;
                                ABUS = 1'b1;
                                LDZ = 1'b1;
                                M = 1'b1;
                            end
                            if (W2) begin // 长周期第 2 拍：取下一条指令。
                                PCINC = 1'b1;
                                LIR = 1'b1;
                            end
                        end
                        4'b1110: begin // STP：停机，拉高 STOP 保持暂停状态。
                            if (W1) begin // 停机节拍：不再推进 PC/IR。
                                STOP = 1'b1;
                            end
                        end
                        4'b1111: begin // DEC：执行自减并写回寄存器，同时更新 Z/C。
                            if (W1) begin // 长周期第 1 拍：执行自减，结果写回寄存器并更新标志位。
                                DRW = 1'b1;
                                CIN = 1'b1;
                                ABUS = 1'b1;
                                LDZ = 1'b1;
                                LDC = 1'b1;
                                S = 4'b1111;
                            end
                            if (W2) begin // 长周期第 2 拍：取下一条指令。
                                PCINC = 1'b1;
                                LIR = 1'b1;
                            end
                        end
                    endcase
                end
            end
        endcase
    end

endmodule

