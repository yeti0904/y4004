import std.ascii;

string LowerString(string str) {
	string ret;
	
	foreach (ref ch ; str) {
		ret ~= toLower(ch);
	}
	
	return ret;
}
