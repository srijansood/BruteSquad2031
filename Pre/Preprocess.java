import java.util.Arrays;

/**
 * Serves as a helper class for the
 * DE2Bot Travelling Salesbot Problem
 * Takes in a starting co-ordinate and 12 others
 * and returns the optimal ordering in which the robot
 * should visit them
 */
public class Preprocess {
    private static Coordinate[] inCoords = new Coordinate[13];
    private static Coordinate[] outCoords  = new Coordinate[13];

    /**
     * Uses graph traversal algorithms to decide the optimal ordering of points
     */
    public static void magic() {
        System.out.println("---Magic Begin---");
        outCoords = Arrays.copyOf(inCoords, inCoords.length);
        System.out.println("---Magic End---");
    }

    public static void main(String[] args) throws Exception {
        System.out.println("---Main Begin---");
        outCoords = new AssemblyWriter().initialize();
        inCoords = AssemblyWriter.populate();
        magic();
        AssemblyWriter.writeToASM();
        System.out.println("---Main End---");
    }
}
