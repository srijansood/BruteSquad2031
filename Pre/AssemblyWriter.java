import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.lang.Integer;
import java.util.ArrayList;
import java.util.Arrays;

import java.io.FileNotFoundException;
import java.io.IOException;
import org.json.simple.parser.ParseException;

import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;


public class AssemblyWriter {

    private final static File ASMFILE = new File(new File("").getAbsoluteFile().getParent() + "/ASM/move_to_points.ASM");

    private static Coordinate[] inCoords = new Coordinate[12];
    private static Coordinate[] outCoords  = new Coordinate[12];

    /**
     * Initializes global variables
     */
    public Coordinate[] initialize() {
        System.out.println("---Initialize Begin---");
        System.out.println("ASM file: " + ASMFILE);
        for (int i = 0; i < inCoords.length; i++)
            inCoords[i] = new Coordinate();
        for (int i = 0; i < outCoords.length; i++)
            outCoords[i] = new Coordinate();
        System.out.println("---Initialize End---");
        return outCoords;
    }

    /**
     * Reads JSON file and populate Coordinate arrays
     */
    public static Coordinate[] populate() throws FileNotFoundException, IOException, ParseException {
        System.out.println("---populate Begin---");
        JSONParser parser = new JSONParser();
		JSONObject jsonObject = (JSONObject) parser.parse(new FileReader(new File("").getAbsoluteFile().getParent() + "/Pre/coords.json"));
        for (int i = 0; i < inCoords.length; i++) {
            JSONArray r = (JSONArray) jsonObject.get(Integer.toString(i + 1));
            inCoords[i].x = Integer.valueOf((int) (long) r.get(0));
            inCoords[i].y = Integer.valueOf((int) (long) r.get(1));
            inCoords[i].setNumber(i + 1);
            System.out.printf("%d. Num: %d x: %d y: %d\n", i, inCoords[i].getNumber(), inCoords[i].getX(),  inCoords[i].getY());
        }
        System.out.println("---populate End---");
        return inCoords;
    }

    /**
     * Writes the modified order of coordinates back to ASM file
     */
    public static void writeToASM(Coordinate[] toWrite) throws FileNotFoundException, IOException {
        System.out.println("---writeToASM Begin---");
        outCoords = toWrite;
        BufferedReader reader = new BufferedReader(new FileReader(ASMFILE));
        String line;
        ArrayList<String> out = new ArrayList<>();

        while ((line = reader.readLine()) != null && !(line.trim().equals(";COORDINATE_TABLE_BEGIN"))) {
            out.add(line + "\n");
        }
        if (line != null) {
            out.add(line + "\n");
        }
        out.add("\tCOORDINATE_TABLE:\n");
        for (int i = 0; i < outCoords.length; i++) {
            out.add(String.format("\t\tDW %d ; x\n", outCoords[i].getX()));
            out.add(String.format("\t\tDW %d ; y\n", outCoords[i].getY()));
            out.add(String.format("\t\tDW %d ; dest #%d\n", outCoords[i].getNumber(), outCoords[i].getNumber()));
        }

        //seek
        while((line = reader.readLine()) != null && !(line.trim().equals(";COORDINATE_TABLE_END")));
        if ( line != null) {
            out.add(line + "\n");
        }

        while ((line = reader.readLine()) != null) {
            out.add(line + "\n");
        }
        reader.close();

		BufferedWriter writer = new BufferedWriter(new FileWriter(ASMFILE));
        for(String s : out)
            writer.write(s);
        writer.flush();
        writer.close();
        System.out.println("---writeToASM End---");
    }

    public static int toRobotUnits(int feetValue) {
        return 0;
    }

}
