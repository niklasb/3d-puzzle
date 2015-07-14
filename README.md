In diesem Ordner befinden sich die gesammelten elektronischen
Erzeugnisse der Gruppe "3D-Puzzle" auf der Modellierungswoche 2009.


=== Grids und Cubes ===

Jeder Würfel ist durch seine Teile definiert. Die Dateien im Ordner
"cubes" enthalten solche Definitionen von 6er-Tupeln von
Puzzleteilen. Die Bedingungen für den Aufbau eines Würfels werden
in sogenannten Grid-Definitionsdateien (Grid = Gitter) gespeichert.
Sie befinden sich im Unterordner "grids" und legen fest, welche
Kanten und Ecken für ein Puzzlenetz übereinstimmen müssen.

Für den 6er-Würfel (5x5x6, wegen 6 Teilen mit der Kantenlänge 5)
wird die Datei grids/5x5x6.rb als Parameter an die Scripts übergeben.


=== Scripts ===

Es handelt sich um Ruby-Scripts, der entsprechende Interpreter für
Windows kann z.B. unter http://rubyforge.org/frs/download.php/69035/rubyinstaller-1.9.1-p378-rc2.exe bezogen
werden.


define_cube.rb  -- Einen Würfel "interaktiv" eingeben. Erwartet wird
	           für jedes Teil eine Bitkette, die es beschreibt.
	           Die Bitkette beginnt mit dem zweiten Bit in der
	           oberen Kante:

                    1 0 1 0 1
                    1       0
                    0       0
                    1 1 0 1 1

	           würde also zu 01010011011011

dump_cube.rb    -- Einen Würfel ausgeben (erwartet wird eine von
		   define_cube.rb generierte Würfeldefinition).
		   Das obige Teil würde wie folgt dargestellt werden:

		    O   O   O
                    O

                    O O   O O

solve_puzzle.rb -- Unser Puzzle-Lösungs-Programm. Kann nicht nur Würfel
		   lösen sondern auch alle möglichen anderen Varianten.
		   Die Parameter können aufgelistet werden, indem man
		   das Script ohne Parameter aufruft.

		   Die Interpretation der Ausgaben im "Verbose Mode"
		   folgt einem speziellen Schema: In der Grid-Definition
		   wird ein gewisses Gitter festgelegt. solve_puzzle.rb
		   gibt nun als eine Lösung für alle Positionen in
		   diesem Gitter die Nummer des Teils an, welches auf der
		   Position liegt, und dessen Orientierung (0 bis 7).
		   Falls jemand Interesse an dem Programm hat, für
		   den die eher problematische Ausgabe ein Hindernis
		   darstellt, darf gerne eine Mail an den Autor des Script
		   geschrieben werden: niklas.baumstark@gmail.com
		   Feedback erwünscht ;)

generate_puzzle.rb -- Unvollständiges Tool zum Erstellen eines Puzzles.


=== Beispielaufrufe ===

# Würfel definieren
ruby define_cube.rb cubes/neuer_wuerfel.yml

# Würfel ausgeben
ruby dump_cube.rb cubes/hc1.yml

# Puzzle lösen
ruby solve_puzzle.rb grids/5x5x6.rb cubes/hc1.yml
# mit Schwierigkeitsmaß
ruby solve_puzzle.rb -r grids/5x5x6.rb cubes/hc1.yml
# Lösungen ausgeben
ruby solve_puzzle.rb -v grids/5x5x6.rb cubes/hc1.yml
# Für Statistiken: CSV Ausgabe benutzen (Beispiel in bash unter Linux)
(echo -n "hc1,"; ruby solve_puzzle.rb -r -c grids/5x5x6.rb cubes/hc1.yml) \
      >> stats.csv


=== Interna ===

Orientierungen:

	0   - Normalstellung
	1   - 90° nach links gedreht
	2   - 180° gedreht
	3   - 90° nach rechts (oder 270° nach links) gedreht
	4   - an der Diagonale von links oben nach rechts unten
	      umgedreht (Vorderseite nach hinten)
	5-7 - wie 1-3, nur mit Orientierung 4 als Ausgangsstellung

puzzle_lib.rb:
     Die Puzzle-Bibliothek, auf der alle Frontend-Scripts aufbauen.
     Recht unkommentiert, aber selbsterklärende Namen etc.


=== Kontakt und Support ;) ===

Bei Fragen einfach eine Mail an niklas.baumstark@gmail.com schreiben.
