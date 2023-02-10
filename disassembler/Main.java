import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.NoSuchFileException;
import java.util.ArrayList;

public class Main {
    public static void main(String[] args) {
        try (InputStream in = new FileInputStream(args[0])) {
            ArrayList<Integer> elf = new ArrayList<>();
            int b = in.read();
            while (b != -1) {
                elf.add(b);
                b = in.read();
            }
            Disassembler dis = new Disassembler(elf);
            dis.parseElf(args[1]);
        } catch (NoSuchFileException e) {
            System.out.println("Where is elf-file? Give me my file!");
        } catch (IOException e) {
            System.out.println("IOException");
        } catch (DisassemblerException e) {
            System.out.println(e.getMessage());
        }
    }
}
