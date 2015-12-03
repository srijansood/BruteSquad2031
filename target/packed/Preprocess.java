import java.util.Arrays;
import java.util.Collections;
import java.lang.Math;
import java.util.List;
import java.util.ArrayList;
import java.util.Set;

import org.jgrapht.alg.HamiltonianCycle;
import org.jgrapht.alg.KruskalMinimumSpanningTree;

import org.jgrapht.*;
import org.jgrapht.graph.*;
import org.jgrapht.traverse.*;
import org.jgrapht.graph.builder.UndirectedWeightedGraphBuilder;
import org.jgrapht.ext.JGraphModelAdapter;
import org.jgraph.JGraph;
import javax.swing.JFrame;

/**
* Serves as a helper class for the
* DE2Bot Travelling Salesbot Problem
* Takes in a starting co-ordinate and 12 others
* and returns the optimal ordering in which the robot
* should visit them
*/
public class Preprocess {
    private static Coordinate[] inCoords = new Coordinate[12];
    private static Coordinate[] outCoords  = new Coordinate[12];
    Coordinate origin = new Coordinate(0,0);

    static Graph<Coordinate, DefaultEdge> graph;
    JGraphModelAdapter<Coordinate, DefaultEdge> jgraphAdapter;

    /**
     * Uses the nearest neighbor approximation
     */
    public List<Coordinate> nearestNeighbor(Graph<Coordinate, DefaultEdge> duplGraph) {
        System.out.println("---NN Begin---");
        Coordinate vertex = origin;
        double pathLength = 0;
        int count = 0;
        List<Coordinate> list = new ArrayList<>();
        list.add(vertex);
        while((duplGraph.vertexSet()).size() > 1) {
            Set<DefaultEdge> edges = duplGraph.edgesOf(vertex);
            DefaultEdge minEdge = minimumEdge(duplGraph, edges);
            //System.out.printf("---\nSource - %s\nTarget - %s\n- ", duplGraph.getEdgeSource(minEdge), duplGraph.getEdgeTarget(minEdge));
            pathLength += duplGraph.getEdgeWeight(minEdge);
            duplGraph.removeVertex(vertex);
            vertex = duplGraph.getEdgeTarget(minEdge) == vertex ? duplGraph.getEdgeSource(minEdge) : duplGraph.getEdgeTarget(minEdge);
            list.add(vertex);
        }
        System.out.println("Path - " + list);
        System.out.println("---NN End---\n");
        return list;
    }

    /**
     * Finds the minimum spanning tree using Kruskal's algorithm
     */
    public double kruskalPath(Graph<Coordinate, DefaultEdge> graph) {
        System.out.println("---Kruskal Begin---");
        Set<DefaultEdge> set = new KruskalMinimumSpanningTree(graph).getMinimumSpanningTreeEdgeSet();
        double weight = new KruskalMinimumSpanningTree(graph).getMinimumSpanningTreeTotalWeight();

        List<DefaultEdge> list = new ArrayList<>();
        int newNumber = 0;
        for (DefaultEdge e : set) {
            if (graph.getEdgeSource(e).getNumber() == newNumber) {
                list.add(graph.getEdgeSource(e));
                list.add(graph.getEdgeTarget(e));
                newNumber = graph.getEdgeTarget(e).getNumber();
            }
            //System.out.printf("---\nSource - %s\nTarget - %s\n- ",graph.getEdgeSource(e), graph.getEdgeTarget(e));
        }

        System.out.println(set);
        System.out.println(weight);
        System.out.println("---Kruskal End--\n");
        return weight;
    }

    public List<Coordinate> magic(SimpleWeightedGraph<Coordinate, DefaultEdge> duplGraph){
        System.out.println("---Magic Begin---");
        duplGraph.removeVertex(origin);
        List<Coordinate> list = HamiltonianCycle.getApproximateOptimalForCompleteGraph(duplGraph);
        duplGraph.addVertex(origin);
        DefaultEdge first = graph.getEdge(origin, list.get(0));
        DefaultEdge end = graph.getEdge(origin, list.get(list.size() - 1));
        if (graph.getEdgeWeight(first) < graph.getEdgeWeight(end)) {
            //start with first
            list.add(0, origin);
        } else {
            Collections.reverse(list);
            list.add(0, origin);
        }

        System.out.println("Path - " + list);
        System.out.println("---Magic End---\n");
        return list;
    }

    public static void main(String[] args) throws Exception {
        System.out.println("---Main Begin---");
        outCoords = new AssemblyWriter().initialize();
        inCoords = AssemblyWriter.populate();
        Preprocess p = new Preprocess();
        graph = p.createGraph();
        //p.visualize();
        //System.out.println("outCoords - " + Arrays.toString(outCoords));
        //p.kruskalPath(p.createGraph());

        List<Coordinate> nnList = p.nearestNeighbor(p.createGraph());
        List<Coordinate> magicList = p.magic((SimpleWeightedGraph) p.createGraph());


        System.out.println("NN Path Length - " + getPathLength(graph, nnList));
        System.out.println("Magic Path Length - " + getPathLength(graph, magicList));

        List<Coordinate> uselist;
        if (getPathLength(graph, nnList) < getPathLength(graph, magicList)) {
            uselist = nnList;
            System.out.println("Using Nearest Neighbors!");
        } else {
            uselist = magicList;
            System.out.println("Using Magic!");
        }

        outCoords = uselist.subList(1, uselist.size()).toArray(outCoords);
        AssemblyWriter.writeToASM(outCoords);
        System.out.println("---Main End---\n");
    }

    /* --- HELPERS --- */
    /**
     * Creates a graph from the loaded Coordinates
     */
    public Graph<Coordinate, DefaultEdge> createGraph() {
        UndirectedWeightedGraphBuilder graphBuilder = new UndirectedWeightedGraphBuilder(new SimpleWeightedGraph(DefaultWeightedEdge.class));
        for (Coordinate c : inCoords)
            graphBuilder.addVertex(c);
        graphBuilder.addVertex(origin);
        for (int i = 0; i < inCoords.length; i++) {
            graphBuilder.addEdge(inCoords[i], origin,  distance(inCoords[i], origin));
            for (int j = i; j < inCoords.length; j++) {
                if (i != j) {
                    graphBuilder.addEdge(inCoords[i], inCoords[j],  distance(inCoords[i], inCoords[j]));
                    //System.out.printf("Adding-\n%s and \n%s\nEdge weight %f\n---\n", inCoords[i], inCoords[j], distance(inCoords[i], inCoords[j]));
                }
            }
        }
        return graphBuilder.build();
    }

    public DefaultEdge minimumEdge(Graph<Coordinate, DefaultEdge> someGraph, Set<DefaultEdge> edgeSet) {
        DefaultEdge e = null;
        double minWeight = Double.MAX_VALUE;
        for (DefaultEdge some : edgeSet) {
            if (someGraph.getEdgeWeight(some) < minWeight) {
                minWeight = someGraph.getEdgeWeight(some);
                e = some;
            }
        }
        return e;
    }

    public static double getPathLength(Graph<Coordinate, DefaultEdge> duplGraph, List<Coordinate> path) {
        double pathLength = 0;
        Coordinate prev = path.get(0);
        for (int i = 1; i < path.size(); i++) {
            DefaultEdge edge = graph.getEdge(prev, path.get(i));
            pathLength += duplGraph.getEdgeWeight(edge);
            prev = path.get(i);
        }
        return pathLength;
    }

    /**
     * Finds the distance between two Coordinates
     */
    public static double distance(Coordinate a, Coordinate b) {
        return (double) Math.sqrt((double)
        (Math.pow(a.getX() - b.getX(), 2) +
        Math.pow(a.getY() - b.getY(), 2))
        );
    }

    /**
     * Visualizes the created graph
     */
    public void visualize() throws InterruptedException {
        JGraph jgraph = new JGraph(new JGraphModelAdapter(graph));
        JFrame frame = new JFrame();
        frame.setSize(400, 400);
        frame.getContentPane().add(jgraph);
        frame.setVisible(true);
        while (true) {
            Thread.sleep(2000);
        }
    }
}
