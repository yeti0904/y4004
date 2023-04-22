import std.stdio;
import std.format;
import std.algorithm;
import core.stdc.stdlib;
import intel4004;

struct Registers {
	ubyte     acc; // accumulator
	bool      carry;
	bool      link; // TODO: find out what this is
	bool      sign; // same for this
	bool      parity; // and this
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
	bool      running = true;
	ubyte     ramAddress;
	ubyte     romAddress;

	this() {
		regs.pc ~= 0;
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

	ubyte ReadRegPair(ubyte pair) {
		return (
			cast(ubyte) (regs.index[pair * 2] << 4) |
			regs.index[(pair * 2) + 1]
		);
	}

	void WriteRamCharacter(ushort address, ubyte value) {
		if (address & 1) {
			ram[address / 2] &= 0xF0;
			ram[address / 2] |= value;
		}
		else {
			ram[address / 2] &= 0x0F;
			ram[address / 2] |= value << 4;
		}
	}

	ubyte ReadRamCharacter(ushort address) {
		if (address & 1) {
			return ram[address / 2] & 0x0F;
		}
		else {
			return ram[address / 2] & 0xF0;
		}
	}

	ushort TopPC() {
		return regs.pc[$ - 1];
	}

	ushort Get12Address() {
		return ((rom[TopPC()] & 0b00001111) << 8) & rom[TopPC() + 1];
	}

	void Next() {
		++ regs.pc[$ - 1];
	}

	void RunBigInstruction() {
		ubyte inst = rom[TopPC()];

		switch (inst) {
			case ByteInstructions.WRM: {
				WriteRamCharacter(ramAddress, regs.acc);
				Next();
				break;
			}
			case ByteInstructions.WMP: assert(0);
			case ByteInstructions.WRR: assert(0);
			case ByteInstructions.WR0: assert(0);
			case ByteInstructions.WR1: assert(0);
			case ByteInstructions.WR2: assert(0);
			case ByteInstructions.WR3: assert(0);
			case ByteInstructions.SBM: assert(0);
			case ByteInstructions.RDM: {
				regs.acc = ReadRamCharacter(ramAddress);
				Next();
				break;
			}
			case ByteInstructions.RDR: assert(0);
			case ByteInstructions.ADM: {
				regs.acc += ReadRamCharacter(ramAddress);

				if (regs.acc & 0xF0) {
					regs.carry = true;
				}
				regs.acc &= 0x0F;
				Next();
				break;
			}
			case ByteInstructions.RD0: assert(0);
			case ByteInstructions.RD1: assert(0);
			case ByteInstructions.RD2: assert(0);
			case ByteInstructions.RD3: assert(0);
			case ByteInstructions.CLB: {
				regs.acc   = 0;
				regs.carry = false;
				Next();
				break;
			}
			case ByteInstructions.CLC: {
				regs.carry = false;
				Next();
				break;
			}
			case ByteInstructions.IAC: {
				++ regs.acc;

				if (regs.acc & 0xF0) {
					regs.carry = true;
				}
				regs.acc &= 0x0F;

				Next();
				break;
			}
			case ByteInstructions.CMC: {
				regs.carry = !regs.carry;
				Next();
				break;
			}
			case ByteInstructions.CMA: {
				regs.acc = cast(ubyte) (~regs.acc);
				Next();
				break;
			}
			case ByteInstructions.RAL: {
				// not sure about this
				regs.acc   <<= 1;
				regs.acc   |=  regs.carry? 1 : 0;
				regs.carry =   (regs.acc & 0xF0) > 0;
				regs.acc   &=  0x0F;
				Next();
				break;
			}
			case ByteInstructions.RAR: {
				// or this
				ubyte oldAcc = regs.acc;
				regs.acc   >>= 1;
				regs.acc   |=  (regs.carry? 1 : 0) << 7;
				regs.carry =   (oldAcc & 1) > 0;
				Next();
				break;
			}
			case ByteInstructions.TCC: {
				regs.acc   = regs.carry? 1 : 0;
				regs.carry = false;
				Next();
				break;
			}
			case ByteInstructions.DAC: {
				-- regs.acc;

				if (regs.acc == 0x0F) {
					regs.carry = true;
				}
				Next();
				break;
			}
			case ByteInstructions.TCS: {
				regs.acc   = regs.carry? 10 : 9;
				regs.carry = false;
				Next();
				break;
			}
			case ByteInstructions.STC: {
				regs.carry = true;
				Next();
				break;
			}
			case ByteInstructions.DAA: {
				if (regs.carry || (regs.acc > 9)) {
					regs.acc += 6;
				}
				if (regs.acc & 0xF0) {
					regs.carry = true;
				}
				regs.acc &= 0x0F;
				Next();
				break;
			}
			case ByteInstructions.KBP: {
				switch (regs.acc) {
					case 0b0000: {
						regs.acc = 0b0000;
						break;
					}
					case 0b0001: {
						regs.acc = 0b0001;
						break;
					}
					case 0b0010: {
						regs.acc = 0b0010;
						break;
					}
					case 0b0100: {
						regs.acc = 0b0011;
						break;
					}
					case 0b1000: {
						regs.acc = 0b0100;
						break;
					}
					default: {
						regs.acc = 0xFF;
						break;
					}
				}
				
				Next();
				break;
			}
			case ByteInstructions.DCL: assert(0);
			default: assert(0);
		}
	}

	void RunSmallInstruction() {
		ubyte inst  = rom[TopPC()] >> 4;
		ubyte param = rom[TopPC()] & 0x0F;

		switch (inst) {
			case NibbleInstructions.NOP: {
				Next();
				break;
			}
			case NibbleInstructions.JCN: {
				bool doJump = false;
				Next();

				if (param & 0b0100) {
					doJump = regs.acc == 0;
				}
				if (param & 0b0010) {
					doJump = regs.carry;
				}
				if (param & 0b0001) {
					doJump = false; // test condition idk
				}
				if (param & 0b1000) {
					doJump = !doJump;
				}

				if (doJump) {
					regs.pc[$ - 1] = (regs.pc[$ - 1] & 0x0F00) | rom[TopPC()];
				}
				else {
					Next();
				}
				break;
			}
			case NibbleInstructions.FIM_SRC: {
				if (param & 1) { // SRC
					ubyte addr = ReadRegPair((param & 0b1110) >> 1);

					ramAddress = addr;
					romAddress = addr;
				}
				else { // FIM
					Next();
					ubyte value = rom[TopPC()];

					WriteRegPair((param & 0b1110) >> 1, value);
				}

				Next();
				break;
			}
			case NibbleInstructions.FIN_JIN: {
				if (param & 1) { // JIN
					regs.pc[$ - 1] = ReadRegPair((param & 0b1110) >> 1);
				}
				else { // FIN
					ushort addr = (TopPC() & 0x0F00) | (ReadRegPair(0));

					WriteRegPair((param & 0b1110) >> 1, rom[addr]);
					Next();
				}
				break;
			}
			case NibbleInstructions.JUN: {
				Next();
				regs.pc[$ - 1] = (param << 8) | rom[TopPC()];
				break;
			}
			case NibbleInstructions.JMS: {
				Next();
				regs.pc ~= (param << 8) | rom[TopPC()];
				break;
			}
			case NibbleInstructions.INC: {
				++ regs.index[param];
				regs.index[param] |= 0x0F;
				Next();
				break;
			}
			case NibbleInstructions.ISZ: {
				++ regs.index[param];
				regs.index[param] |= 0x0F;
				Next();

				if (regs.index[param] == 0) {
					Next();
				}
				else {
					regs.pc[$ - 1] = (TopPC() & 0x0F00) | rom[TopPC()];
				}
				break;
			}
			case NibbleInstructions.ADD: {
				regs.acc += regs.index[param];

				if ((regs.acc & 0xF0) > 0) {
					regs.carry = true;
				}
				regs.acc &= 0x0F;

				Next();
				break;
			}
			case NibbleInstructions.SUB: {
				regs.acc += ~regs.index[param];
				regs.acc += regs.carry? 1 : 0;

				if ((regs.acc & 0x0F0) > 0) {
					regs.carry = true;
				}
				regs.acc &= 0x0F;

				Next();
				break;
			}
			case NibbleInstructions.LD: {
				regs.acc = regs.index[param];
				Next();
				break;
			}
			case NibbleInstructions.XCH: {
				swap(regs.acc, regs.index[param]);
				Next();
				break;
			}
			case NibbleInstructions.BBL: {
				regs.pc  = regs.pc.remove(regs.pc.length - 1);
				regs.acc = param;
				break;
			}
			case NibbleInstructions.LDM: {
				regs.acc = param;
				Next();
				break;
			}
			default: assert(0);
		}
	}

	void RunInstruction() {
		ubyte inst = rom[TopPC()];

		/*writefln(
			"Running instruction %X (%s)", inst,
			Instruction.ToString(Instruction.FromByte(inst))
		);*/

		if ((inst >> 4) >= 0b1110) {
			RunBigInstruction();
		}

		RunSmallInstruction();

		if (TopPC() > 0x0FFF) {
			running = false;
		}
	}
}
