import std.conv;
import std.file;
import std.stdio;
import std.string;
import core.stdc.stdlib;
import intel4004;
import error;
import util;

enum TokenType {
	Instruction,
	Parameter,
	Label,
	Identifier,
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
			case TokenType.Label:
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

	void AddLabel() {
		tokens  ~= Token(TokenType.Label, reading, fname, line, col);
		tokens  ~= Token(TokenType.End, "", fname, line, col);
		reading  = "";
	}

	void AddParameter() {
		if (isNumeric(reading)) {
			tokens  ~= Token(
				TokenType.Parameter, parse!int(reading), fname, line, col
			);
		}
		else {
			tokens ~= Token(TokenType.Identifier, reading, fname, line, col);
		}
		reading = "";
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
				case ':': {
					if (strip(reading) == "") {
						EmptyLabelError(fname, line, col);
						success = false;
						break;
					}

					AddLabel();
					break;
				}
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
	Lexer          lexer;
	ubyte[]        bin;
	ushort[string] symbols;

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
		if (
			(lexer.tokens[i].type != TokenType.Parameter) &&
			(lexer.tokens[i].type != TokenType.Identifier)
		) {
			ParameterExpected(
				lexer.tokens[i].fname, lexer.tokens[i].line, lexer.tokens[i].col
			);
			exit(1);
		}
	}

	bool SymbolExists(string name) {
		return (name in symbols) !is null;
	}

	void GenerateSymbols() {
		ushort totalSize = 0;
		symbols          = null;
		
		foreach (i, ref token ; lexer.tokens) {
			switch (token.type) {
				case TokenType.Instruction: {
					Instruction inst = Instruction.FromString(token.str);

					if (inst.size == 2) {
						totalSize += 1;
					}
					else {
						switch (inst.nibblei) {
							case NibbleInstructions.JCN:
							case NibbleInstructions.JUN:
							case NibbleInstructions.JMS:
							case NibbleInstructions.ISZ: {
								totalSize += 2;
								break;
							}
							case NibbleInstructions.FIM_SRC: {
								switch (LowerString(token.str)) {
									case "fim": {
										totalSize += 2;
										break;
									}
									default: {
										totalSize += 1;
										break;
									}
								}
								break;
							}
							default: {
								totalSize += 1;
							}
						}
					}

					break;
				}
				case TokenType.Label: {
					symbols[token.str] = totalSize;
					break;
				}
				default: continue;
			}
		}
	}

	void AssembleFile(string fname) {
		lexer.fname = fname;
		lexer.Lex(readText(fname));

		if (!lexer.success) {
			stderr.writefln("Lexing failed");
			exit(1);
		}

		GenerateSymbols();

		for (size_t i = 0; i < lexer.tokens.length; ++i) {
			auto token = lexer.tokens[i];

			if (token.type == TokenType.Label) {
				++ i;
				continue;
			}
			
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
						ubyte condition;

						ParameterRequired(i);

						if (lexer.tokens[i].type != TokenType.Parameter) {
							IntegerExpected(
								lexer.tokens[i].fname,
								lexer.tokens[i].line, lexer.tokens[i].col
							);
						}

						condition = lexer.tokens[i].integer & 0x0F;

						++ i;
						ParameterRequired(i);

						ubyte address;
						
						switch (lexer.tokens[i].type) {
							case TokenType.Parameter: {
								address = lexer.tokens[i].integer & 0xFF;
								break;
							}
							case TokenType.Identifier: {
								if (!SymbolExists(lexer.tokens[i].str)) {
									NonexistantLabelError(
										lexer.tokens[i].fname,
										lexer.tokens[i].line, lexer.tokens[i].col,
										lexer.tokens[i].str
									);
									exit(1);
								}
							
								address = symbols[lexer.tokens[i].str] & 0xFF;
								break;
							}
							default: assert(0);
						}

						bin ~= (cast(ubyte) NibbleInstructions.JCN << 4) |
							(condition & 0x0F);
						bin ~= address;
						
						break;
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
						ushort address;
					
						ParameterRequired(i);
						
						switch (lexer.tokens[i].type) {
							case TokenType.Parameter: {
								address = cast(ushort) lexer.tokens[i].integer;
								break;
							}
							case TokenType.Identifier: {
								if (!SymbolExists(lexer.tokens[i].str)) {
									NonexistantLabelError(
										lexer.tokens[i].fname,
										lexer.tokens[i].line, lexer.tokens[i].col,
										lexer.tokens[i].str
									);
									exit(1);
								}
							
								address = symbols[lexer.tokens[i].str];
								break;
							}
							default: assert(0);
						}
					
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
						switch (lexer.tokens[i].type) {
							case TokenType.Parameter: {
								bin ~= cast(ubyte) lexer.tokens[i].integer;
								break;
							}
							case TokenType.Identifier: {
								if (!SymbolExists(lexer.tokens[i].str)) {
									NonexistantLabelError(
										lexer.tokens[i].fname,
										lexer.tokens[i].line, lexer.tokens[i].col,
										lexer.tokens[i].str
									);
									exit(1);
								}
							
								bin ~= symbols[lexer.tokens[i].str] & 0xFF;
								break;
							}
							default: assert(0);
						}
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
