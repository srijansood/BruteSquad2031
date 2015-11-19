import org.jgrapht.*;
import org.jgrapht.generate.*;
import org.jgrapht.graph.*;
import org.jgrapht.traverse.*;

public class Coordinate extends DefaultEdge {
    int x, y, number;

    Coordinate() {
        this.x = 0;
        this.y = 0;
        this.number = 0;
    }

    Coordinate(int x, int y) {
        this.x = x;
        this.y = y;
    }


    public int getX() {
        return x;
    }

    public int getY() {
        return y;
    }

    public int getNumber() {
        return number;
    }

    public void setX(int x) {
        this.x = x;
    }

    public void setY(int y) {
        this.y = y;
    }

    public void setNumber(int number) {
        this.number = number;
    }

    public String toString() {
        return String.format("Num: %d x: %d y: %d\n", getNumber(),getX(),  getY());
    }
}
