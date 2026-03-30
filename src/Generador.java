

import java.io.File;
import java.io.FileReader;
import java.io.InputStreamReader;
import java.util.Scanner;

/**
 * Genera MiLexico.java a partir de lexico.flex usando JFlex.
 * Ejecutar este main antes de compilar el proyecto si se modifica lexico.flex.
 */
public class Generador {

    public static void main(String[] args) {

        Scanner teclado = new Scanner(System.in);

        System.out.println("=== Analizador Léxico ===");
        System.out.println("¿Desde dónde desea leer?");
        System.out.println("  1 - Desde lexico.flex");
        System.out.println("  2 - Desde lexico_indentacion.flex");
        System.out.print("Ingrese su opción: ");

        String opcion = teclado.nextLine().trim();
        teclado.close();
        String path;
        if (opcion.equals("1")) {
            path = "./src/lexico.flex";
        } else if (opcion.equals("2")) {
            path = "./src/lexico_indentacion.flex";
        } else {
            System.err.println("Opción inválida. Saliendo.");
            return;
        }
        System.out.println("Generando léxico desde: " + path);
        File file = new File(path);
        jflex.generator.LexGenerator generator = new jflex.generator.LexGenerator(file);
        generator.generate();
        System.out.println("MiLexico.java generado correctamente.");
    }
}
