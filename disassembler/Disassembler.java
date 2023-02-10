import java.io.FileWriter;
import java.io.IOException;
import java.io.Writer;
import java.util.ArrayList;
import java.util.List;

public class Disassembler {
    private static ArrayList<Integer> elf;
    private SymbolTable symbolTable;
    private static Writer writer;
    private int addrSectionHeaderTable;
    private int countSectionHeaders;
    private int sizeSecHedPart;
    private int addrShStrTab;
    private static int addrStrTab;
    private int addrSymTab;
    private int sizeSymTab;
    private int addrText;
    private int sizeText;
    private int virtualAddrText;
    private int numForL = 0;
    private final String outputFormat3 = "   %05x:\t%08x\t%7s\t%s, %s, %s\n";
    private final String outputFormat2Hex = "   %05x:\t%08x\t%7s\t%s, 0x%h\n";
    private final String outputFormatLSJ = "   %05x:\t%08x\t%7s\t%s, %s(%s)\n";
    private final String outputFormatJarl = "   %05x:\t%08x\t%7s\t%s, 0x%h <%s>\n";
    private final String outputFormatB = "   %05x:\t%08x\t%7s\t%s, %s, 0x%h <%s>\n";
    private final String outputFormatEF = "   %05x:\t%08x\t%7s\n";

    Disassembler(ArrayList<Integer> elf) {
            Disassembler.elf = elf;
    }

    public void parseElf(String outputFile) throws IOException {
        writer = new FileWriter(outputFile);
        try {
            checkFile();
            addrSectionHeaderTable = getBytes(0x20, 4);
            countSectionHeaders = getBytes(0x30, 2);
            sizeSecHedPart = getBytes(0x2E, 2);

            int idxShStrTab = getBytes(0x32, 2);
            addrShStrTab = getBytes(addrSectionHeaderTable + idxShStrTab * sizeSecHedPart + 0x10, 4);

            int idxSymTab = findSectionIdx(".symtab");
            addrSymTab = getBytes(addrSectionHeaderTable + idxSymTab * sizeSecHedPart + 0x10, 4);
            sizeSymTab = getBytes(addrSectionHeaderTable + idxSymTab * sizeSecHedPart + 0x14, 4);

            int idxStrTab = findSectionIdx(".strtab");
            addrStrTab = getBytes(addrSectionHeaderTable + idxStrTab * sizeSecHedPart + 0x10, 4);

            int idxText = findSectionIdx(".text");
            addrText = getBytes(addrSectionHeaderTable + idxText * sizeSecHedPart + 0x10, 4);
            sizeText = getBytes(addrSectionHeaderTable + idxText * sizeSecHedPart + 0x14, 4);
            virtualAddrText = getBytes(addrSectionHeaderTable + idxText * sizeSecHedPart + 0x0C, 4);

            parseSymTab();

            writer.write(".text\n");
            for (int i = 0; i < sizeText / 4; i++) {
                parseTextPart(i);
            }
            for (int i = 0; i < sizeText / 4; i++) {
                writer.write(parseTextPart(i));
            }

            symbolTable.print();
        } finally {
            writer.close();
        }
    }

    private static int getBytes(int firstByte, int countBytes) {
        int bytes = 0;
        for (int i = 0; i < countBytes; i++) {
            bytes += elf.get(firstByte + i) << (8 * i);
        }
        return bytes;
    }
    private int getInLine(int line, int begin, int end) {
        int result = 0;
        for (int i = begin; i <= end; i++) {
            result |= ((line >> i) & 1) << i;
        }
        return result >> begin;
    }

    private String parseTextPart(int i) {
        int currAddr = addrText + 4 * i;
        int line = getBytes(currAddr, 4);
        int vAddr = virtualAddrText + 4 * i;
        String ans = "";
        if (symbolTable.isMark(vAddr)) {
            ans += String.format("%08x   <%s>:\n", vAddr, symbolTable.getMark(vAddr));
        }

        String rd = getRegName(getInLine(line, 7, 11));
        String rs1 = getRegName(getInLine(line, 15, 19));
        String rs2 = getRegName(getInLine(line, 20, 24));
        int funct3 = getInLine(line, 12, 14);
        int funct7 = getInLine(line, 25, 31);
        int opcode = getInLine(line, 0, 6);
        String command = "";

        switch (opcode) {
            case 0b0110111 -> {
                command = "lui";
                int c = getInLine(line, 12, 31);
                ans += String.format(outputFormat2Hex, vAddr, getBytes(currAddr, 4), command, rd, c);
            }
            case 0b0010111 -> {
                command = "auipc";
                int c = getInLine(line, 12, 31);
                ans += String.format(outputFormat2Hex, vAddr, getBytes(currAddr, 4), command, rd, c);
            }
            case 0b1101111 -> {
                command = "jal";
                int c = getInLine(line, 31, 31) << 20;
                c |= getInLine(line,12, 19) << 12;
                c |= getInLine(line, 20, 20) << 11;
                c |= getInLine(line,21 , 30) << 1;
                c = virtualAddrText + c + i * 4;
                String mark = getMark(c);
                ans += String.format(outputFormatJarl, vAddr, getBytes(currAddr, 4), command, rd, c, mark);
            }
            case 0b1100111 -> {
                command = "jalr";
                int c = getInLine(line, 20, 31);
                ans += String.format(outputFormatLSJ, vAddr, getBytes(currAddr, 4), command, rd, c, rs1);
            }
            case 0b1100011 -> {
                switch (funct3) {
                    case 0b000 -> command = "beq";
                    case 0b001 -> command = "bne";
                    case 0b100 -> command = "blt";
                    case 0b101 -> command = "bge";
                    case 0b110 -> command = "bltu";
                    case 0b111 -> command = "bgeu";
                }
                int c = getInLine(line, 31, 31) << 12;
                c |= getInLine(line,7, 7) << 11;
                c |= getInLine(line, 25, 30) << 5;
                c |= getInLine(line,8 , 11) << 1;
                String mark = getMark(vAddr + c);
                ans += String.format(outputFormatB, vAddr, getBytes(currAddr, 4), command, rs1, rs2, vAddr + c, mark);
            }
            case 0b0000011 -> {
                switch (funct3) {
                    case 0b000 -> command = "lb";
                    case 0b001 -> command = "lh";
                    case 0b010 -> command = "lw";
                    case 0b100 -> command = "lbu";
                    case 0b101 -> command = "lhu";
                }
                int c = getInLine(line, 20, 31);
                ans += String.format(outputFormatLSJ, vAddr, getBytes(currAddr, 4), command, rd, c, rs1);
            }
            case 0b0100011 -> {
                switch (funct3) {
                    case 0b000 -> command = "sb";
                    case 0b001 -> command = "sh";
                    case 0b010 -> command = "sw";
                }
                int c = (getInLine(line, 25, 31) << 5) + getInLine(line, 7, 11);
                ans += String.format(outputFormatLSJ, vAddr, getBytes(currAddr, 4), command, rs2, c, rs1);
            }
            case 0b0010011 -> {
                switch (funct3) {
                    case 0b001, 0b101 -> {
                        switch (funct3) {
                            case 0b001 -> command = "slli";
                            case 0b101 -> {
                                switch (funct7) {
                                    case 0b0000000 -> command = "srli";
                                    case 0b0100000 -> command = "srai";
                                }
                            }
                        }
                        int c = getInLine(line, 20, 24);
                        return String.format(outputFormat3, vAddr, getBytes(currAddr, 4), command, rd, rs1, c);
                    }
                    default -> {
                        switch (funct3) {
                            case 0b000 -> command = "addi";
                            case 0b010 -> command = "slti";
                            case 0b011 -> command = "sltiu";
                            case 0b100 -> command = "xori";
                            case 0b110 -> command = "ori";
                            case 0b111 -> command = "andi";
                        }
                        int c = getInLine(line, 20, 31);
                        ans += String.format(outputFormat3, vAddr, getBytes(currAddr, 4), command, rd, rs1, c);
                    }
                }
            }
            case 0b0110011 -> {
                switch (funct7) {
                    case 0b0000001 -> {
                        switch (funct3) {
                            case 0b000 -> command = "mul";
                            case 0b001 -> command = "mulh";
                            case 0b010 -> command = "mulhsu";
                            case 0b011 -> command = "mulhu";
                            case 0b100 -> command = "div";
                            case 0b101 -> command = "divu";
                            case 0b110 -> command = "rem";
                            case 0b111 -> command = "remu";
                        }
                    }
                    case 0b0000000 -> {
                        switch (funct3) {
                            case 0b000 -> command = "add";
                            case 0b001 -> command = "sll";
                            case 0b010 -> command = "slt";
                            case 0b011 -> command = "sltu";
                            case 0b100 -> command = "xor";
                            case 0b101 -> command = "srl";
                            case 0b110 -> command = "or";
                            case 0b111 -> command = "and";
                        }
                    }
                    case 0b0100000 -> {
                        switch (funct3) {
                            case 0b000 -> command = "sub";
                            case 0b101 -> command = "sra";
                        }
                    }
                }
                ans += String.format(outputFormat3, vAddr, getBytes(currAddr, 4), command, rd, rs1, rs2);
            }
            case 0b1110011 -> {
                switch (getBytes(currAddr + 2, 1) >> 4) {
                    case 0b0000 -> command = "ecall";
                    case 0b0001 -> command = "ebreak";
                }
                ans += String.format(outputFormatEF, vAddr, getBytes(currAddr, 4), command);
            }
            case 0b0001111 -> {
                command = "fence";
                ans += String.format(outputFormatEF, vAddr, getBytes(currAddr, 4), command);
            }
            default -> ans += String.format(outputFormatEF, vAddr, getBytes(currAddr, 4), "unknown_instruction");
        }
        return ans;
    }

    private void parseSymTab() {
        symbolTable = new SymbolTable();
        for (int i = 0; i < sizeSymTab / 16; i++) {
            int nameInt = getBytes(addrSymTab + i * 16, 4);
            int value = getBytes(addrSymTab + i * 16 + 4, 4);
            int size = getBytes(addrSymTab + i * 16 + 8, 4);
            int info = getBytes(addrSymTab + i * 16 + 12, 1);
            int other = getBytes(addrSymTab + i * 16 + 13, 1);
            int shndx = getBytes(addrSymTab + i * 16 + 14, 2);
            SymbolTablePart part = new SymbolTablePart(List.of(i, value, size, info & 15, info >> 4, other & 3, shndx, nameInt));
            part.addInSymTab(symbolTable);
        }
    }

    private int findSectionIdx(String name) {
        int i = 0;
        while (i < countSectionHeaders) {
            int firstByteOfSectionHeader = addrSectionHeaderTable + sizeSecHedPart * i;
            int addrInShSrtTab = addrShStrTab + getBytes(firstByteOfSectionHeader, 4);
            String nameOfSection = readString(addrInShSrtTab);
            if (nameOfSection.equals(name)) {
                return i;
            }
            i++;
        }
        throw new DisassemblerException("There is no " + name + " header in file.");
    }

    public static void print(String str) throws IOException {
        writer.write(str);
    }

    public static String readName(int num) {
        return readString(addrStrTab + num);
    }
    public static String readString(int addr) {
        int j = 1;
        char chr = (char) getBytes(addr, 1);
        StringBuilder str = new StringBuilder();
        while ((int) chr != 0) {
            str.append(chr);
            chr = (char) getBytes(addr + j, 1);
            j++;
        }
        return str.toString();
    }
    private String getMark(int addr) {
        if (symbolTable.isMark(addr)) {
            return symbolTable.getMark(addr);
        }
        String newMark = "L" + numForL++;
        symbolTable.addInMarks(addr, newMark);
        return newMark;
    }
    private void checkFile() {
        if (getBytes(0x04, 1) != 1) {
            throw new DisassemblerException("Not 32-bit format. Such file format not supported.");
        }
        if (getBytes(0x05, 1) != 1) {
            throw new DisassemblerException("Not little endian. Such file format not supported.");
        }
        if (getBytes(0x12, 2) != 0xF3) {
            throw new DisassemblerException("Not RISC-V. Such file format not supported.");
        }
    }
    private String getRegName(int num) {
        return switch (num) {
            case 0 -> "zero";
            case 1 -> "ra";
            case 2 -> "sp";
            case 3 -> "gp";
            case 4 -> "tp";
            case 5, 6, 7 -> "t" + (num - 5);
            case 8, 9 -> "s" + (num - 8);
            case 10, 11, 12, 13, 14, 15, 16, 17 -> "a" + (num - 10);
            case 18, 19, 20, 21, 22, 23, 24, 25, 26, 27 -> "s" + (num - 16);
            case 28, 29, 30, 31 -> "t" + (num - 25);
            default -> null;
        };
    }
}