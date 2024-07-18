target:bf bfc bfs
bf: bf.c
	cc bf.c -o bf -lfsize
	sudo cp bf /usr/bin/
bfc:bfc.c
	cc bfc.c -o bfc
bfs:bfs.c
	cc bfs.c -o bfs
