JFLAGS = -cp *:.
JVM = java
JC = javac
DATE = `date +%d-%m-%y::%H-%M-%S_%p`
COORD = coords.json

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

#compiles and runs Preprocess
run:
ifneq ($(COORD), coords.json)
	cp -f $(COORD) coords.json
endif
	$(MAKE) classes
	$(JVM) $(JFLAGS) $(MAIN) > log.txt

#resets the ASM file, runs
debug:
		cp -f ../ASM/move_to_points-duplicate.ASM ../ASM/move_to_points.ASM
		$(MAKE) run

#resets ASM, removes extra files
clean:
		cp -f ../ASM/move_to_points-duplicate.ASM ../ASM/move_to_points.ASM
		$(RM) ../target/move_to_points.ASM
		$(RM) ../target/packed/*
		$(RM) *.class
		$(RM) BruteSquad.tar

#packs the code in a tar
pack:
	cp -f ../ASM/move_to_points.ASM ../target/move_to_points.ASM
	cp -rf * ../target/packed/
	git add ../target/
	git commit -m "Packed at "$(DATE)
	git push

lab: run
	$(MAKE) pack
