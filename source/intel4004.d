import std.format;

enum NibbleInstructions {
	NOP = 0b0000,
	JCN = 0b0001,
	FIM_SRC = 0b0010,
	FIN_JIN = 0b0011,
	JUN = 0b0100,
	JMS = 0b0101,
	INC = 0b0110,
	ISZ = 0b0111,
	ADD = 0b1000,
	SUB = 0b1001,
	LD  = 0b1010,
	XCH = 0b1011,
	BBL = 0b1100,
	LDM = 0b1101
}

enum ByteInstructions {
	WRM = 0b11100000,
	WMP = 0b11100001,
	WRR = 0b11100010,
	WR0 = 0b11100100,
	WR1 = 0b11100101,
	WR2 = 0b11100110,
	WR3 = 0b11100111,
	SBM = 0b11101000,
	RDM = 0b11101001,
	RDR = 0b11101010,
	ADM = 0b11101011,
	RD0 = 0b11101100,
	RD1 = 0b11101101,
	RD2 = 0b11101110,
	RD3 = 0b11101111,
	CLB = 0b11110000,
	CLC = 0b11110001,
	IAC = 0b11110010,
	CMC = 0b11110011,
	CMA = 0b11110100,
	RAL = 0b11110101,
	RAR = 0b11110110,
	TCC = 0b11110111,
	DAC = 0b11111000,
	TCS = 0b11111001,
	STC = 0b11111010,
	DAA = 0b11111011,
	KBP = 0b11111100,
	DCL = 0b11111101,
	HLT = 0b11111111
}

enum Condition {
	INVERT   = 0,
	ACCZERO  = 2, // accumulator = 0
	CLONE    = 4, // carry/link = 1
	TESTZERO = 8  // test pin = 0
}

class InstructionException : Exception {
	this(string msg, string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line);
	}
}

struct Instruction {
	ubyte size; // in nibbles
	union {
		NibbleInstructions nibblei;
		ByteInstructions   bytei;
	}

	this(NibbleInstructions pnibblei) {
		size    = 1;
		nibblei = pnibblei;
	}

	this(ByteInstructions pbytei) {
		size  = 2;
		bytei = pbytei;
	}

	static Instruction FromString(string inst) {
		switch (inst) {
			case "nop": return Instruction(NibbleInstructions.NOP);
			case "jcn": return Instruction(NibbleInstructions.JCN);
			case "fim":
			case "src": return Instruction(NibbleInstructions.FIM_SRC);
			case "fin":
			case "jin": return Instruction(NibbleInstructions.FIN_JIN);
			case "jun": return Instruction(NibbleInstructions.JUN);
			case "jms": return Instruction(NibbleInstructions.JMS);
			case "inc": return Instruction(NibbleInstructions.INC);
			case "isz": return Instruction(NibbleInstructions.ISZ);
			case "add": return Instruction(NibbleInstructions.ADD);
			case "sub": return Instruction(NibbleInstructions.SUB);
			case "ld":  return Instruction(NibbleInstructions.LD);
			case "xch": return Instruction(NibbleInstructions.XCH);
			case "ldm": return Instruction(NibbleInstructions.LDM);

			case "wrm": return Instruction(ByteInstructions.WRM);
			case "wmp": return Instruction(ByteInstructions.WMP);
			case "wrr": return Instruction(ByteInstructions.WRR);
			case "wr0": return Instruction(ByteInstructions.WR0);
			case "wr1": return Instruction(ByteInstructions.WR1);
			case "wr2": return Instruction(ByteInstructions.WR2);
			case "wr3": return Instruction(ByteInstructions.WR3);
			case "sbm": return Instruction(ByteInstructions.SBM);
			case "rdm": return Instruction(ByteInstructions.RDM);
			case "rdr": return Instruction(ByteInstructions.RDR);
			case "adm": return Instruction(ByteInstructions.ADM);
			case "rd0": return Instruction(ByteInstructions.RD0);
			case "rd1": return Instruction(ByteInstructions.RD1);
			case "rd2": return Instruction(ByteInstructions.RD2);
			case "rd3": return Instruction(ByteInstructions.RD3);
			case "clb": return Instruction(ByteInstructions.CLB);
			case "clc": return Instruction(ByteInstructions.CLC);
			case "iac": return Instruction(ByteInstructions.IAC);
			case "cmc": return Instruction(ByteInstructions.CMC);
			case "cma": return Instruction(ByteInstructions.CMA);
			case "ral": return Instruction(ByteInstructions.RAL);
			case "rar": return Instruction(ByteInstructions.RAR);
			case "tcc": return Instruction(ByteInstructions.TCC);
			case "dac": return Instruction(ByteInstructions.DAC);
			case "tcs": return Instruction(ByteInstructions.TCS);
			case "stc": return Instruction(ByteInstructions.STC);
			case "daa": return Instruction(ByteInstructions.DAA);
			case "kbp": return Instruction(ByteInstructions.KBP);
			case "dcl": return Instruction(ByteInstructions.DCL);
			case "hlt": return Instruction(ByteInstructions.HLT);

			default: throw new InstructionException(
				format("Unknown instruction %s"), inst
			);
		}
	}

	static string ToString(Instruction inst) {
		if (inst.size == 1) {
			switch (inst.nibblei) {
				case NibbleInstructions.NOP:     return "nop";
				case NibbleInstructions.JCN:     return "jcn";
				case NibbleInstructions.FIM_SRC: return "fim_src";
				case NibbleInstructions.FIN_JIN: return "fin_jin";
				case NibbleInstructions.JUN:     return "jun";
				case NibbleInstructions.JMS:     return "jms";
				case NibbleInstructions.INC:     return "inc";
				case NibbleInstructions.ISZ:     return "isz";
				case NibbleInstructions.ADD:     return "add";
				case NibbleInstructions.SUB:     return "sub";
				case NibbleInstructions.LD:      return "ld";
				case NibbleInstructions.XCH:     return "xch";
				case NibbleInstructions.BBL:     return "bbl";
				case NibbleInstructions.LDM:     return "ldm";
				default: assert(0 && "program bug");
			}
		}
		else if (inst.size == 2) {
			switch (inst.bytei) {
				case ByteInstructions.WRM: return "dcl";
				case ByteInstructions.WMP: return "kbp";
				case ByteInstructions.WRR: return "daa";
				case ByteInstructions.WR0: return "stc";
				case ByteInstructions.WR1: return "tcs";
				case ByteInstructions.WR2: return "dac";
				case ByteInstructions.WR3: return "tcc";
				case ByteInstructions.SBM: return "rar";
				case ByteInstructions.RDM: return "ral";
				case ByteInstructions.RDR: return "cma";
				case ByteInstructions.ADM: return "cmc";
				case ByteInstructions.RD0: return "iac";
				case ByteInstructions.RD1: return "clc";
				case ByteInstructions.RD2: return "clb";
				case ByteInstructions.RD3: return "rd3";
				case ByteInstructions.CLB: return "rd2";
				case ByteInstructions.CLC: return "rd1";
				case ByteInstructions.IAC: return "rd0";
				case ByteInstructions.CMC: return "adm";
				case ByteInstructions.CMA: return "rdr";
				case ByteInstructions.RAL: return "rdm";
				case ByteInstructions.RAR: return "sbm";
				case ByteInstructions.TCC: return "wr3";
				case ByteInstructions.DAC: return "wr2";
				case ByteInstructions.TCS: return "wr1";
				case ByteInstructions.STC: return "wr0";
				case ByteInstructions.DAA: return "wrr";
				case ByteInstructions.KBP: return "wmp";
				case ByteInstructions.DCL: return "wrm";

				default: assert(0 && "program bug");
			}
		}

		throw new Exception("BUG!!!");
	}

	static Instruction FromByte(ubyte b) {
		if (b >> 4 >= 0b1110) {
			return Instruction(cast(ByteInstructions) b);
		}
		else {
			return Instruction(cast(NibbleInstructions) b >> 4);
		}
	}
}
