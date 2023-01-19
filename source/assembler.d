import std.conv;
import std.file;
import std.stdio;
import std.string;
import core.stdc.stdlib;
import intel4004;
import error;

enum TokenType {
	Instruction,
	Parameter,
	End
}

struct Token {
	TokenType type;
	string    fname;
	size_t    line, col;
	
	union {
		int    integer;
		string str;
	}

	this(TokenType ptype, int pinteger, string pfname, size_t pline, size_t pcol) {
		type    = ptype;
		integer = pinteger;
		fname   = pfname;
		line    = pline;
		col     = pcol;
	}

	this(TokenType ptype, string pstr, string pfname, size_t pline, size_t pcol) {
		type  = ptype;
		str   = pstr;
		fname = pfname;
		line  = pline;
		col   = pcol;
	}

	string toString() {
		string contents;
		switch (type) {
			case TokenType.Instruction: {
				contents = str;
				break;
			}
			case TokenType.Parameter: {
				contents = text(integer);
				break;
			}
			case TokenType.End: {
				break;
			}
			default: assert(0);
		}
		return format("(%s: '%s')\n", type, contents);
	}
}

class Lexer {
	Token[] tokens;
	string  fname;
	string  reading;
	size_t  line, col;
	bool    success;

	this() {}
	~this() {}

	bool IsInstruction() {
		return (tokens.length == 0) || (tokens[$ - 1].type == TokenType.End);
	}

	void AddInstruction() {
		tokens  ~= Token(TokenType.Instruction, reading, fname, line, col);
		reading  = "";
	}

	void AddParameter() {
		if (!isNumeric(reading)) {
			InvalidIntegerError(fname, line, col, reading);
			success = false;
			return;
		}

		tokens  ~= Token(TokenType.Parameter, parse!int(reading), fname, line, col);
		reading  = "";
	}

	void AddEnd() {
		tokens  ~= Token(TokenType.End, "", fname, line, col);
		reading  = "";
	}

	void Lex(string code) {
		line    = 1;
		col     = 1;
		success = true;
	
		for (size_t i = 0; i < code.length; ++i) {
			if (code[i] == '\n') {
				++ line;
				col = 1;
			}
			else {
				++ col;
			}
				
			switch (code[i]) {
				case '\n': {
					if (strip(reading) == "") {
						break;
					}
				
					if (IsInstruction()) {
						AddInstruction();
					}
					else {
						AddParameter();
					}

					AddEnd();
					break;
				}
				case ',': {
					if (strip(reading) == "") {
						break;
					}
				
					if (IsInstruction()) {
						CommaAfterInstructionError(fname, line, col);
						success = false;
					}
					else {
						AddParameter();
					}
					break;
				}
				case '\t':
				case ' ': {
					if (strip(reading) == "") {
						break;
					}
				
					if (IsInstruction()) {
						AddInstruction();
					}
					else {
						ExpectedCommaError(fname, line, col);
						success = false;
					}
					break;
				}
				default: {
					reading ~= code[i];
				}
			}
		}
	}
}

class Assembler {
	Lexer   lexer;
	ubyte[] bin;

	this() {
		lexer = new Lexer();
	}
	~this() {}

	static Assembler Instance() {
		static Assembler instance;

		if (!instance) {
			instance = new Assembler();
		}

		return instance;
	}

	void ParameterRequired(size_t i) {
		if (lexer.tokens[i].type != TokenType.Parameter) {
			ParameterExpected(
				lexer.tokens[i].fname, lexer.tokens[i].line, lexer.tokens[i].col
			);
			exit(1);
		}
	}

	void AssembleFile(string fname) {
		lexer.fname = fname;
		lexer.Lex(readText(fname));

		if (!lexer.success) {
			stderr.writefln("Lexing failed");
			exit(1);
		}

		for (size_t i = 0; i < lexer.tokens.length; ++i) {
			auto token = lexer.tokens[i];
			if (lexer.tokens[i].type != TokenType.Instruction) {
				ExpectedInstructionError(token.fname, token.line, token.col);
				exit(1);
			}

			Instruction instruction;

			try {
				instruction = Instruction.FromString(token.str);
			}
			catch (InstructionException e) {
				ErrorBegin(token.fname, token.line, token.col);
				stderr.writeln(e.msg);
				exit(1);
			}

			++ i;

			if (instruction.size == 1) {
				switch (instruction.nibblei) {
					case NibbleInstructions.NOP: {
						bin ~= 0;
						break;
					}
					case NibbleInstructions.JCN: {
						// TODO
						assert(0);
					}
					case NibbleInstructions.FIM_SRC: {
						// TODO
						assert(0);
					}
					case NibbleInstructions.FIN_JIN: {
						// TODO
						assert(0);
					}
					case NibbleInstructions.JUN:
					case NibbleInstructions.JMS: {
						ParameterRequired(i);
						ushort address = cast(ushort) lexer.tokens[i].integer;
						bin ~= cast(ubyte) (
							(cast(ubyte) instruction.nibblei << 4) |
							(address & 0xF00)
						);
						bin ~= (address & 0xFF);
						break;
					}
					case NibbleInstructions.INC:
					case NibbleInstructions.ADD:
					case NibbleInstructions.SUB:
					case NibbleInstructions.LD:
					case NibbleInstructions.XCH:
					case NibbleInstructions.BBL:
					case NibbleInstructions.LDM: {
						ParameterRequired(i);
						bin ~= cast(ubyte)
							(cast(ubyte) instruction.nibblei << 4) |
							(lexer.tokens[i].integer & 0x0F);
						break;
					}
					case NibbleInstructions.ISZ: {
						ParameterRequired(i);
						bin ~= cast(ubyte)
							(cast(ubyte) instruction.nibblei << 4) |
							(lexer.tokens[i].integer & 0x0F);
						++ i;
						ParameterRequired(i);
						bin ~= cast(ubyte) lexer.tokens[i].integer;
						break;
					}
					default: assert(0);
				}
			}
			else if (instruction.size == 2) {
				if (lexer.tokens[i].type != TokenType.End) {
					ParametersError(token.fname, token.line, token.col);
					exit(1);
				}

				bin ~= cast(ubyte) instruction.bytei;
			}
			++ i;
		}
	}
}
