/* Analizador Léxico - Compiladores UNNOBA 2026 */

/**
 * Analizador léxico para el TP Compilador 2026.
 *
 * Manejo de indentación significativa (tipo Python):
 *   - Al comienzo de cada línea no vacía se mide su indentación.
 *   - Si es mayor que el tope de la pila  → se emite INDENT.
 *   - Si es menor                         → se emiten tantos DEDENT como
 *       niveles se cierren (puede ser más de uno por línea).
 *   - Al llegar al EOF se cierran todos los niveles abiertos con DEDENT.
 *
 * Dado que JFlex solo puede retornar un token por llamada a yylex(), los
 * tokens adicionales (DEDENTs múltiples, NEWLINE pendiente, etc.) se
 * encolan en `pendingTokens` y se devuelven en las siguientes llamadas,
 * ANTES de volver a invocar al scanner interno.
 *
 * El parser llama a next_token() (generado por CUP), aquí sobreescrito
 * para drenar la cola primero.
 */
%%

%public
%class Lexer
%unicode
%type Token
%line
%column

%{
    /* ─────────────────────────────────────────────────────────────────────
     * Variables de instancia
     * ───────────────────────────────────────────────────────────────────── */

    // ── Indentación significativa ────────────────────────────────────────
    /** Pila de niveles de indentación. El fondo siempre es 0. */
    java.util.Deque<Integer> indentStack = new java.util.ArrayDeque<>();

    /**
     * Cola de tokens generados pero aún no entregados al parser.
     * Se usa cuando una sola acción léxica produce más de un token
     */
    java.util.Queue<Token> pendingTokens = new java.util.LinkedList<>();

    /** Nivel de indentación acumulado mientras se escanea LINE_START. */
    int pendingIndent = 0;

    // Bloque de inicialización de instancia
    {
        indentStack.push(0);    // nivel base: columna 0
    }

    /* ─────────────────────────────────────────────────────────────────────
     * Métodos auxiliares para construir tokens
     * ───────────────────────────────────────────────────────────────────── */
    private Token token(String nombre) {
        return new Token(nombre, yyline, yycolumn);
    }

    private Token token(String nombre, Object valor) {
        return new Token(nombre, yyline, yycolumn, valor);
    }

    private Token token(String nombre, int line, int col, Object valor) {
        return new Token(nombre, line, col, valor);
    }

    /* ─────────────────────────────────────────────────────────────────────
     * processIndent(indent, line, col)
     *
     * Compara `indent` con el tope de la pila y produce los tokens
     * necesarios.  El primero se retorna; los adicionales van a
     * pendingTokens para ser entregados en llamadas posteriores.
     *
     *   indent > top  →  devuelve INDENT  (apila nuevo nivel)
     *   indent < top  →  devuelve DEDENT y encola N x DEDENT
     * ───────────────────────────────────────────────────────────────────── */
    private void processIndent(int indent, int line, int col) {
        int top = indentStack.peek();

        if (indent > top) {
            indentStack.push(indent);
            pendingTokens.add(new Token("INDENT", line, col));

        } else if (indent < top) {
            while (indentStack.peek() > indent) {
                indentStack.pop();
                pendingTokens.add(new Token("DEDENT", line, col));
            }

            // Verificar consistencia del nivel
            if (indentStack.peek() != indent) {
                throw new RuntimeException("Error: indentación inconsistente en línea " + line);
            }
        }
    }


    /* ─────────────────────────────────────────────────────────────────────
     * next_token() — requerido por java_cup.runtime.Scanner.
     * Sobrescribe el método generado por JFlex para manejar la cola de tokens
     *
     * Flujo:
     *   1. Si hay tokens pendientes, los entrega de a uno.
     *   2. Si no, llama a yylex().
     *   3. Si yylex() retorna null (EOF), cierra bloques con DEDENT y
     *      entrega el primero.
     *   4. Cuando la cola se vacía tras el EOF, retorna null: scan() de
     *      CUP lo convierte en END_OF_FILE.
     * ───────────────────────────────────────────────────────────────────── */
    public Token next_token() throws java.io.IOException {
        if (!pendingTokens.isEmpty()) {
            return pendingTokens.poll();
        }
        Token t = yylex();
        if (t == null) {
            processIndent(0, yyline, yycolumn);
            t = pendingTokens.isEmpty() ? null : pendingTokens.poll();
        }
        return t;
    }
%}



/* ── Espacios y terminadores ────────────────────────────────────────────── */
LineTerminator = \r\n | \r | \n
HSpace         = [ \t]

/* ── Línea en blanco (sólo espacios + fin de línea) ────────────────────── */
BlankLine      = {HSpace}* {LineTerminator}

/* ── Estados adicionales ────────────────────────────────────────────────── */
%state LINE_START


%%

/* ════════════════════════════════════════════════════════════════════════
   LINE_START
   Mide la indentación al comienzo de una línea nueva.
   Transiciona a YYINITIAL cuando encuentra el primer carácter real.
   ════════════════════════════════════════════════════════════════════════ */
<LINE_START> {

    /* Línea completamente en blanco → ignorar  */
    {BlankLine}  {}

    /* Espacio simple: un nivel                                            */
    " "   { pendingIndent++; }

    /* Tabulación: suma 4                    */
    "\t"  { pendingIndent +=  4; }

    /* Primer carácter real: procesar cambio de indentación               */
    [^ \t\r\n] {
                   yypushback(1);              // devolver el carácter para que sea leído por el YYINITIAL
                   yybegin(YYINITIAL);
                   processIndent(pendingIndent, yyline, yycolumn);
                   pendingIndent = 0;
                   if (!pendingTokens.isEmpty()) {
                       return pendingTokens.poll();
                   }
               }
}


/* ════════════════════════════════════════════════════════════════════════
   YYINITIAL — análisis normal dentro de una línea
   ════════════════════════════════════════════════════════════════════════ */
<YYINITIAL> {

    /* ── Código ─────────────────────────────────────────────────── */
    "CODE"             { return token("CODE",   yytext()); }
    {LineTerminator}   {
                         yybegin(LINE_START);
                       }  

}


/* ── Carácter ilegal (fallback) ──────────────────────────────────────── */
[^] { return token("ERROR", "Error: carácter ilegal <" + yytext() + ">"); }