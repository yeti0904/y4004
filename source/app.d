import std.stdio;
import core.stdc.stdlib;
import emulator;

void main() {
	Emulator emulator;

	void OnEnd() {
		writeln(emulator.regs);
		exit(0);
	}
	
	emulator = Emulator.Instance();

	emulator.SetRAMSize(640);
	emulator.SetROMSize(4096);

	emulator.Load([0xD2, 0xB0, 0xDE, 0x80]);

	while (true) {
		try {
			emulator.RunInstruction();
		}
		catch (EmulatorException e) {
			writeln(e.msg);
			OnEnd();
		}
	}
}
