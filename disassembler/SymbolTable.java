import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

public class SymbolTable {
    private ArrayList<SymbolTablePart> symTab;
    private final Map<Integer, String> marks;

    SymbolTable() {
        symTab = new ArrayList<>();
        marks = new HashMap<>();
    }

    public void add(SymbolTablePart part) {
        symTab.add(part);
    }
    public void add(SymbolTablePart part, int value, String name) {
        symTab.add(part);
        marks.put(value, name);
    }
    public boolean isMark(int value) {
        return marks.containsKey(value);
    }
    public String getMark(int value) {
        return marks.get(value);
    }

    public void addInMarks(int value, String mark) {
        marks.put(value, mark);
    }
    public void print() throws IOException {
        Disassembler.print("\n.symtab\n");
        Disassembler.print("Symbol Value          	  Size Type 	Bind 	 Vis   	   Index Name\n");
        for (SymbolTablePart part : symTab) {
            Disassembler.print(part.toFormatString());
        }
    }
}
