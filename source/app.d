import std.file;
import std.stdio;
import core.stdc.stdlib;
import emulator;
import assembler;

const string appHelp = "
-e / --emulator  : run the intel 4004 emulator
-a / --assembler : run the intel 4004 assembler
-o / --output    : select output file for intel 4004 assembler
-h / --help      : show this message
";

enum AppMode {
	Emulate,
	Assemble
}

class App {
	Emulator  emulator;
	Assembler assembler;

	this() {}
	~this() {}

	static App Instance() {
		static App instance;

		if (!instance) {
			instance = new App();
		}

		return instance;
	}

	void InitEmulator() {
		emulator = Emulator.Instance();
		
		emulator.SetRAMSize(640);
		emulator.SetROMSize(4096);
	}

	void InitAssembler() {
		assembler = Assembler.Instance();
	}

	void RunEmulator(string fname) {
		try {
			File(fname, "r");
		}
		catch (Exception e) {
			stderr.writeln(e.msg);
			exit(1);
		}
	
		InitEmulator();

		emulator.Load(cast(ubyte[]) read(fname));

		while (emulator.running) {
			emulator.RunInstruction();
		}

		writeln(emulator.regs);
	}

	void RunAssembler(string fname, string outFile) {
		InitAssembler();

		try {
			File(fname, "r");
		}
		catch (Exception e) {
			stderr.writeln(e.msg);
			exit(1);
		}

		assembler.AssembleFile(fname);

		std.file.write(outFile, cast(void[]) assembler.bin);
	}
}

void main(string[] args) {
	auto app     = App.Instance();
	AppMode mode = AppMode.Assemble;
	string fname;
	string outFile = "out.bin";

	for (size_t i = 1; i < args.length; ++i) {
		if (args[i][0] == '-') {
			switch (args[i]) {
				case "-h":
				case "--help": {
					std.stdio.write(appHelp[1 .. $]);
					exit(0);
				}
				case "-e":
				case "--emulator": {
					mode = AppMode.Emulate;
					break;
				}
				case "-a":
				case "--assembler": {
					mode = AppMode.Assemble;
					break;
				}
				case "-o":
				case "--output": {
					++ i;
					if (i == args.length) {
						stderr.writeln("-o/--output used but no filename given");
						exit(1);
					}

					outFile = args[i];
					break;
				}
				default: {
					stderr.writefln("Unrecognised option %s", args[i]);
					exit(1);
				}
			}
		}
		else {
			fname = args[i];
		}
	}

	if (fname == "") {
		stderr.writeln("No file given");
		exit(1);
	}

	switch (mode) {
		case AppMode.Emulate: {
			app.RunEmulator(fname);
			break;
		}
		case AppMode.Assemble: {
			app.RunAssembler(fname, outFile);
			break;
		}
		default: assert(0);
	}
}
