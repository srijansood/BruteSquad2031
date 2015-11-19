JFLAGS = -cp *:.
JVM = java
JC = javac

.SUFFIXES: .java .class

.java.class:
		$(JC) $(JFLAGS) $*.java

CLASSES = \
        AssemblyWriter.java \
        Coordinate.java \
        Preprocess.java \

MAIN = Preprocess

default: run

classes: $(CLASSES:.java=.class)

run: classes
	$(JVM) $(JFLAGS) $(MAIN)
	$(RM) *.class

debug: run
	   cp -f ../ASM/move_to_points-duplicate.ASM ../ASM/move_to_points.ASM

clean:
		$(RM) *.class

pack: clean
	tar zcvf BruteSquad.tar $(CLASSES)
