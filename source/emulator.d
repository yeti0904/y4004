import std.stdio;
import std.format;
import std.algorithm;
import core.stdc.stdlib;
import intel4004;

struct Registers {
	ubyte     acc; // accumulator
	bool      carry;
	ubyte[16] index;
	ushort[]  pc;

	string toString() {
		string str  = "REGISTER DUMP\n=============\n";
		str        ~= format("ACC:   %d\n", acc);
		str        ~= format("CARRY: %d\n", carry);
		foreach (i, ref indexReg ; index) {
			str ~= format("r%d:    %d\n", i, indexReg);
		}
		str ~= "PC STACK\n========\n";
		foreach (ref reg ; pc) {
			str ~= format("%d\n", reg);
		}

		return str;
	}
}

class EmulatorException : Exception {
	this(string msg, string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line);
	}
}

class Emulator {
	ubyte[]   ram;
	ubyte[]   rom;
	Registers regs;
	bool      increment;

	this() {
		regs.pc   ~= 0;
		increment  = true;
	}
	
	~this() {}

	static Emulator Instance() {
		static Emulator instance;

		if (!instance) {
			instance = new Emulator();
		}

		return instance;
	}

	void SetRAMSize(size_t size) {
		ram = new ubyte[](size);
	}

	void SetROMSize(size_t size) {
		rom = new ubyte[](size);
	}

	void Load(ubyte[] program) {
		foreach (i, ref b ; program) {
			rom[i] = b;
		}
	}

	void WriteRegPair(ubyte pair, ubyte value) {
		regs.index[pair * 2]       = (value & 0b11110000) >> 4;
		regs.index[(pair * 2) + 1] = value & 0b00001111;
	}

	ubyte ReadRegPair(ubyte pair, ubyte value) {
		return (
			cast(ubyte) (regs.index[pair * 2] << 4) |
			regs.index[(pair * 2) + 1]
		);
	}

	ushort TopPC() {
		return regs.pc[$ - 1];
	}

	ushort Get12Address() {
		return ((rom[TopPC()] & 0b00001111) << 8) & rom[TopPC() + 1];
	}

	ushort ByteParam() {
		return rom[TopPC() + 1];
	}

	void RunByteInstruction() {
		ubyte inst = rom[TopPC()];

		switch (inst) {
			case ByteInstructions.WRM: {
				break;
			}
			case ByteInstructions.CLB: {
				regs.acc   = 0;
				regs.carry = false;
				break;
			}
			case ByteInstructions.CLC: {
				regs.carry = false;
				break;
			}
			case ByteInstructions.IAC: {
				++ regs.acc;
				regs.acc &= 0b00001111;
				break;
			}
			case ByteInstructions.DAC: {
				-- regs.acc;
				regs.acc &= 0b00001111;
				break;
			}
			case ByteInstructions.STC: {
				regs.carry = true;
				break;
			}
			default: assert(0);
		}
	}

	void RunInstruction() {
		ubyte inst      = (rom[TopPC()] & 0b11110000) >> 4;
		ubyte param     = rom[TopPC()] & 0b00001111;
		
		switch (inst) {
			case NibbleInstructions.NOP: {
				break;
			}
			case NibbleInstructions.JCN: {
				// TODO
				break;
			}
			case NibbleInstructions.FIM_SRC: {
				if (inst & 1) { // SRC
					// TODO: WHAT ARE REGISTER PAIRS
				}
				else { // FIM
					// TODO: wtf are register pairs
				}
				break;
			}
			case NibbleInstructions.FIN_JIN: {
				if (inst & 1) { // JIN
					
				}
				else { // FIN
					
				}
				break;
			}
			case NibbleInstructions.JUN: {
				regs.pc[$ - 1] = Get12Address();
				increment = false;
				break;
			}
			case NibbleInstructions.JMS: {
				regs.pc ~= Get12Address();
				increment = false;
				break;
			}
			case NibbleInstructions.INC: {
				++ regs.index[param];
				regs.index[param] &= 0b00001111;
				break;
			}
			case NibbleInstructions.ISZ: {
				++ regs.index[param];

				if (regs.index[param] == 0) {
					regs.pc[$ - 1] = (TopPC() & 0b0000111100000000) & ByteParam();
					increment = false;

					// TODO: case if the instruction is on words 254/255 of a page
				}
				break;
			}
			case NibbleInstructions.ADD: {
				regs.acc   += regs.index[param];
				regs.carry  = regs.acc & 0b00010000? true : false;
				regs.acc   &= 0b00001111;
				break;
			}
			case NibbleInstructions.SUB: {
				// TODO: wtf is one's complement
				regs.acc -= regs.index[param];
				regs.acc &= 0b00001111;
				break;
			}
			case NibbleInstructions.LD: {
				regs.acc = regs.index[param];
				break;
			}
			case NibbleInstructions.XCH: {
				// i think this is right
				ubyte old         = regs.acc;
				regs.acc          = regs.index[param];
				regs.index[param] = old;
				break;
			}
			case NibbleInstructions.BBL: {
				regs.pc   = regs.pc.remove(regs.pc.length - 1);
				increment = false;
				regs.acc  = param;
				break;
			}
			case NibbleInstructions.LDM: {
				regs.acc = param;
				break;
			}
			default: assert(0);
		}

		if (increment) {
			++ regs.pc[$ - 1];

			if (TopPC() >= rom.length) {
				throw new EmulatorException(format("PC > %d", rom.length));
			}
		}
		increment = true;
	}
}
