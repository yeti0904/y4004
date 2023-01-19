import std.stdio;
import core.stdc.stdlib;

void ErrorBegin(string fname, size_t line, size_t col) {
	version (Windows) {
		stderr.writef("%s:%d:%d: error: ", fname, line + 1, col + 1);
	}
	else {
		stderr.writef("\x1b[1m%s:%d:%d: \x1b[31merror:\x1b[0m ", fname, line + 1, col + 1);
	}
}

void InvalidIntegerError(string fname, size_t line, size_t col, string attempt) {
	ErrorBegin(fname, line, col);
	stderr.writefln("Invalid integer: '%s'", attempt);
}

void ExpectedCommaError(string fname, size_t line, size_t col) {
	ErrorBegin(fname, line, col);
	stderr.writeln("Expected comma");
}

void CommaAfterInstructionError(string fname, size_t line, size_t col) {
	ErrorBegin(fname, line, col);
	stderr.writeln("Unexpected comma after instruction");
}

void ExpectedInstructionError(string fname, size_t line, size_t col) {
	ErrorBegin(fname, line, col);
	stderr.writeln("Expected instruction");
}

void ParametersError(string fname, size_t line, size_t col) {
	ErrorBegin(fname, line, col);
	stderr.writeln("This instruction has no parameters");
}

void ParameterExpected(string fname, size_t line, size_t col) {
	ErrorBegin(fname, line, col);
	stderr.writeln("Parameter expected");
}
