import java.util.List;

public class SymbolTablePart {
    private int num;
    private int value;
    private int size;
    private String type;
    private String bind;
    private String vis;
    private String index;
    private String name;
    private final String format = "[%4d] 0x%-15X %5d %-8s %-8s %-8s %6s %s\n";

    SymbolTablePart(List<Integer> inf) {
        num = inf.get(0);
        value = inf.get(1);
        size = inf.get(2);
        type = getType(inf.get(3));
        bind = getBind(inf.get(4));
        vis = getVis(inf.get(5));
        index = getIndex(inf.get(6));
        name = getName(inf.get(7));
    }

    public String toFormatString() {
        return String.format(format, num, value, size, type, bind, vis, index, name);
    }

    public void addInSymTab(SymbolTable symTab) {
        if (type.equals("FUNC")) {
            symTab.add(this, value, name);
        } else {
            symTab.add(this);
        }
    }
    private String getType(int num) {
        return switch (num) {
            case 0 -> "NOTYPE";
            case 1 -> "OBJECT";
            case 2 -> "FUNC";
            case 3 -> "SECTION";
            case 4 -> "FILE";
            case 5 -> "COMMON";
            case 6 -> "TLS";
            case 10 -> "LOOS";
            case 12 -> "HIOS";
            case 13 -> "LOPROC";
            case 15 -> "HIPROC";
            default -> throw new DisassemblerException("There is unsupported type in file.");
        };
    }

    private String getBind(int num) {
        return switch (num) {
            case 0 -> "LOCAL";
            case 1 -> "GLOBAL";
            case 2 -> "WEAK";
            case 10 -> "LOOS";
            case 12 -> "HIOS";
            case 13 -> "LOPROC";
            case 15 -> "HIPROC";
            default -> throw new DisassemblerException("There is unsupported bind in file.");
        };
    }

    private String getVis(int num) {
        return switch (num) {
            case 0 -> "DEFAULT";
            case 1 -> "INTERNAL";
            case 2 -> "HIDDEN";
            case 3 -> "PROTECTED";
            case 4 -> "EXPORTED";
            case 5 -> "SINGLETON";
            case 6 -> "ELIMINATE";
            default -> throw new DisassemblerException("There is unsupported visibility in file.");
        };
    }

    private String getIndex(int num) {
        return switch (num) {
            case 0 -> "UND";
            case 0xff00 -> "BEFORE";
            case 0xff01 -> "AFTER";
            case 0xff02 -> "AMD64_LCOMMON";
            case 0xff1f -> "HIPROC";
            case 0xff20 -> "LOOS";
            case 0xff3f -> "HIOS";
            case 0xfff1 -> "ABS";
            case 0xfff2 -> "COMMON";
            case 0xffff -> "HIRESERVE";
            default -> Integer.toString(num);
        };
    }

    private String getName(int num) {
        if (num == 0) {
            return "";
        } else {
            return Disassembler.readName(num);
        }
    }

}
