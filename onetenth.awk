#!/usr/bin/awk -f

# Copyright (c) 2014, Michael Sliczniak
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
# 
# 1. Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
# 
# 2. Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
# IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
# PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
# TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#       @(#)onetenth.awk    0.5 (mzs) 4/28/14

# initialization
BEGIN {
	seed=""

	# must be lower case
	wkey="h"
	nkey="k"
	skey="j"
	ekey="l"
	qkey="q"

	rows=4
	cols=4

	syms="ABCDEFGHIJKLMNOPQRSTUVWXYZ*"
	high=11

	esym="." # empty symbol

	bl="" # blank lines

	cl="" # clear
	hi=""
	lo=""
	vb=""

	colors=""

	# must match from first character on line
	comment="##"

	# if the first char is |, then it is a command to pipe into
	of=""
}

# print an error message to stderr and then exit with exit status 2
function errexit(s) {
	print "onetenth.awk: " s | "/bin/cat >&2"
	errstat=2
	exit
}

# In the translated board: pick a new random symbol.
function pick(w, h,   j) {
	if (free == 0) return (0)

	# pick a free space and put 1 or 2 on it
	j = int(rand() * free--)

	for (h-=1; h >= 0; h--) {
		j-=w - lpop[h]
		if (j < 0) break

	}

	pickx=w + j
	picky=h

	# this is the reason of the name, one tenth chance to be a value of 2
	if (rand() < 0.1)
		return (2)
	else
		return (1)
}

# In the translated board: move symbols west and merge matching symbols
function merge(w, h,   i, j, sm, x, y, pop, l, last, v) {
	# print ""
	# 
	# for (i=0; i < cells;) {
	# 	printf("%d:", lpop[i / w])
	# 
	# 	for (j=0; j < w; j++) printf(" %d", tran[i++])
	# 
	# 	print ""
	# }

	# shifts and merges
	sm=0

	# Yes this is written in a strange way, user defined functions can
	# be slow in some awks for various reasons, so don't want slow
	# functions in an inner loop.
	#
	# XXX: x and y are not coords on the translated board, should be renamed
	h-=1
	for (y=w * h; y >= 0; y-=w) {
		# how many symbols are there in this line
		pop=lpop[h]

		# print "y=" y " pop=" pop

		if (pop == 0) {
			h--
			continue
		}

		x=y
		l=x

		# find first non empty cell
		last=tran[l++]
		while (last == 0) last=tran[l++]
		if (last < 0) last=-last

		# print "last=" last " l=" l

		while (--pop != 0) {
			# find next non empty cell
			v=tran[l++]
			while (v == 0) v=tran[l++]
			if (v < 0) v=-v

			if (last != v) {
				tran[x++]=last
				last=v

				continue
			}

			free++
			score+=v
			v=-v - 1

			if (v <= -high) won=1

			# if this was the last one, do this little trick
			# to have the correct increased value put into the
			# translated array when breaking out of this while
			# loop
			if (--pop == 0) {
				last=v
				break
			}

			tran[x++]=v

			last=tran[l++]
			while (last == 0) last=tran[l++]
			if (last < 0) last=-last
		} 

		tran[x++]=last

		# update the population of symbols in the current line and
		# ghosts
		lghost[h]+=l - x
		lpop[h--]=x - y

		# update the shifted or moved count
		sm+=l - x
	}

	# print sm
        # 
	# for (i=0; i < cells;) {
	# 	printf("%d:", lpop[i / w])
        # 
	# 	for (j=0; j < w; j++) printf(" %d", tran[i++])
        # 
	# 	print ""
	# }

	return (sm)
}

# handle printing to output pipe or file as well as stdout
function oprint(s) {
	if (op != "")
		printf("%s", s) | op
	else if (of != "")
		printf("%s", s) > of
	else
		printf("%s", s)
}

# print taking into account highlighting
function pprint(v,   h, i, j, c) {
	# oprint(sprintf("%3d>", v))

	if (v == 0) {
		# it's a blank cell
		oprint(sprintf("%s%s", carr[1], esym))
		return
	}

	c=v
	if (v > 0) {
		if (c > colors) c=colors

		# it's not hilighted, just print
		oprint(sprintf("%s%s", 
		  carr[c], substr(syms, (v - 1) * slen + 1, slen)))

		return
	}

	c=-c
	if (c > colors) c=colors

	# it's highlighted
	i=(-v - 1) * slen + 1

	if (v == -1)
		v=esym
	else   
		v=substr(hisyms, i, slen)

	# if there is no hi escape, just print the sym from hisyms
	if (hi == "") {
		oprint(sprintf("%s%s", carr[c], v))
		return
	}

	# set the color
	oprint(carr[c])

	h=substr(losyms, i, slen)

	# if there is no lo escape, then assume each character must be escaped
	if (lo == "") {
		# if first chars is bs, assume trying to bold like nroff
		# will need to print every character before the backspace
		# and then after again
		if (substr(hi, 1, 1) == "\b") {
			for (i=1; i <= slen; i++) {
				j=substr(v, i, 1)
				oprint(sprintf("%s", j))

				if (substr(h, i, 1) != "-") continue

				oprint(sprintf("%s%s", hi, j))
			}

			return
		}

		# the first char of hi is something else, like hi could be '_^H'
		# for example to be a nroff style underline, in this case only
		# print hi followed by the character from the sym for every
		# highlighted character.
		for (i=1; i <= slen; i++) {
			if (substr(h, i, 1) == "-") oprint(sprintf("%s", hi))

			oprint(sprintf("%s", substr(v, i, 1)))
		}

		return
	}

	# There is a hi and a lo escape sequence, the idea then is to print the
	# hi seq, then some hilighted characters, and then the lo escape seq.
	j=0
	for (i=1; i<= slen; i++) {
		if (substr(h, i, 1) == "-") {
			if (j == 0) {
				j=1
				oprint(sprintf("%s", hi))
			}
		} else {
			if (j == 1) {
				j=0
				oprint(sprintf("%s", lo))
			}
		}

		oprint(sprintf("%s", substr(v, i, 1)))
	}

	if (j == 1) oprint(sprintf("%s", lo))
}

# XXX: would be nice to know the first line where a collapse occurred
#      in case visual bell only flashes the line with the cursor.
function idraw(   i, r, c) {
	oprint(sprintf("%s%s", cl, carr[1]))
	if (key == wkey) oprint("Wsne")
	else if (key == skey) oprint("wSne")
	else if (key == nkey) oprint("wsNe")
	else if (key == ekey) oprint("wsnE")
	else oprint("wsne")
	oprint(sprintf(" %x\n", score))

	i=0
	for (r=0; r < rows; r++) {
		oprint(sprintf("%s%s", carr[1], bl))
		for (c=0; c < cols; c++) pprint(board[i++])
		oprint("\n")
	}
}

# draw the board
#
# NB: Since 1 and 1 merge into 2 there can never be -1, so use -1 to
#     signify an empty cell that used to have something before in case
#     drawing is setup to indicate the ghost cell in some manner, say with
#     a visual bell, stand-out mode, or reverse video.
function draw(   s) {
	if (vb == "") {
		# place last picked sym into the draw board
		if (pickv != 0) board[cols * row + col]=pickv

		idraw()

		return
	}

	idraw()

	# place last picked sym into the draw board
	if (pickv != 0) board[cols * row + col]=pickv

	# do the visual bell and then redraw without highlighting,
	# xterm at least has a pause by default of 100ms after a visual
	# bell.

	s=hi
	hi=""
	if (score != lscore) oprint(vb)
	if (delay != "") system(delay)
	idraw()
	hi=s
}

# NB: saving the last picked sym and tucking it into the translated board
# later was a good idea, it was simple and clean to deal with and let me
# make the transforms faster. It made sense when this awk script was just
# for trying-out strategies to play the game because I would not make moves
# where the board would not change. But if you made such a move it added
# a symbol. This makes the game too easy, because sometimes you have to
# move in a way that unlocks the row or column where you have your highest
# valued sym in a corner and you get unlucky and a low value symbol appears
# in that corner. In that version, you could press the direction where nothing
# moves and your high value sym remains in the corner. I should just do away
# with this 'not tucking away the last picked piece until I know what
# direction was selected next' to make it simpler, but I was rushing to
# make the interactive version started by the shell script. So anyway,
# that's why all of these functions now return how much that last piece
# shifted, need to see if there was piece added, and are more complicated.

# XXX: I should comment these, but I so much want to change them and comment
# the new versions instead... See above

function quickest(w, h,   i) {
	if (pickv == 0) return (0)

	i=lpop[picky]++
	tran[w * picky + i]=pickv

	for (h-=1; h >= 0; h--) lghost[h]=0

	i=pickx - i
	lghost[picky]=i

	return (i)
}

# The number of ghosted cells is very easy to determine when they are all
# against the opposite side: if there any cells at all then every cell that
# is now now occupied had a sum travel through so should be counted as ghosted.
#
# The potential trouble happens with the pesky just picked sym. If there is
# another sym in that line anyway, then no problem all the other cells were
# ghosted and the count is correct.
#
# But if it was the only one in the line, then every cell that is to the
# opposite side of where it travels to never had a symbol travel through it
# and should not be counted as ghosted.
#
# One approach is to just treat it like the general case and then at the end
# go back and fix it up if need be.
function quicker(w, h,   yi, yj, popi, popj, i, j, k, s) {
	if (pickv != 0) {
		i=lpop[picky]++
		tran[w * picky + i]=pickv
	}

	# shifted lines
	s=0

	yi=0
	yj=h - 1
	while (yi < yj) {
		# print "yi=" yi " yj=" yj
		popi=lpop[yi]
		popj=lpop[yj]

		# handle line and ghost population
		lpop[yi]=popj
		if (popj != 0) {
			i=w - popj
			lghost[yi]=i

			if (i != 0) s++
		} else {
			lghost[yi]=0
		}

		lpop[yj]=popi
		if (popi != 0) {
			i=w - popi
			lghost[yj]=i

			if (i != 0) s++
		} else {
			lghost[yj]=0
		}

		if (popi > popj) {
			# i,j ... ...
			#   ...
			# ... k

			# i,j ... ...
			#   ...
			# ... ... k

			# ABC yii ...
			#   ...
			# ... k CBA
			i=yi * w
			k=yj * w + popi - 1
			popi-=popj
		} else {
			i=yj * w
			k=yi * w + popj - 1
			j=popi
			popi=popj-popi
			popj=j

		}

		j=i
		yi++
		yj--

		# print "popi=" popi " popj=" popj " i=" i " j=" j " k=" k

		while (popi-- > 0) {
			tran[k--]=tran[j++]
			# print "j=" j, "k=" k
		}

		while (popj-- > 0) {
			# i can be equal to j so copy
			popi=tran[j++]
			tran[i++]=tran[k]
			tran[k--]=popi
			# print "i=" i, "j=" j, "k=" k
		}
	}

	# probably could be handled above, but right now it reverses twice
	# back to the same
	if (yi == yj) {
		popj = lpop[yi]

		# handle ghost count
		if (popj != 0) {
			i=w - popj
			lghost[yi]=i

			if (i != 0) s++
		} else {
			lghost[yi]=0
		}

		j=yi * w
		k=j + popj - 1
		while (j < k) {
			i=tran[j]
			tran[j++]=tran[k]
			tran[k--]=i
		}
	}

	# if nothing was picked, there is nothing to fix-up
	if (pickv == 0) return (s)

	# what the line has been rotated to by 180*
	j=h - picky - 1
	i=lpop[j]

	# if the line was full, nothing ghosted, nothing shifted
	if (i == w) return (s)

	# if it was the only symbol, fix it up
	if (i == 1) lghost[j]-=pickx

	# Now was the only sym in the line up against the edge or did it shift?
	if ((pickx + 1) == w) return (s - 1)

	return (s)
}

# NB: there is probably better way for the 90 degree rotations, the orignial
# script without drawing a board used two arrays, one for horizontal and the
# other for vertical, and never drew a board, it was just concerned if the
# game was won or not.
#
# copy the translated board into the drawing board taking care to zero fill
# then copy out of the drawing board back into the translated board with
# the proper rotation

function cw(w, h,   i, j, x, y, pop, v) {
	# for (i=0; i < cells;) {
	# 	printf("%d:", lpop[i / w])
	# 	for (j=0; j < w; j++) printf(" %d", tran[i++])
	# 	print ""
	# }

	i=0
	for (y=0; y < h; y++) {
		for (x=0; x < lpop[y]; x++) { board[i]=tran[i]; i++ }
		for (; x < w; x++) board[i++]=0
	}

	# print "pickv=" pickv " pickx=" pickx " picky=" picky

	if (pickv != 0) {
		board[w * picky + pickx]=pickv
	}

	# for (i=0; i < cells;) {
	# 	for (j=0; j < w; j++) printf("%d ", board[i++])
	# 	print ""
	# }

	j=0
	for (x=0; x < w; x++) {
		pop=0
		i=cells - w + x
		for (y=0; y < h; y++) {
			v=board[i]; i-=w
			if (v != 0) pop++
			tran[j++]=v
		}

		lpop[x]=pop
		lghost[x]=0
	}

	# for (i=0; i < cells;) {
	# 	printf("%d:", lpop[i / h])
	# 	for (j=0; j < h; j++) printf(" %d", tran[i++])
	# 	print ""
	# }

	return (0)
}

function ccw(w, h,   i, j, x, y, pop, v) {
	# print "w=" w " h=" h
	# 
	# for (i=0; i < cells;) {
	# 	printf("%d:", lpop[i / w])
	# 	for (j=0; j < w; j++) printf(" %d", tran[i++])
	# 	print ""
	# }

	i=0
	for (y=0; y < h; y++) {
		for (x=0; x < lpop[y]; x++) { board[i]=tran[i]; i++ }
		for (; x < w; x++) board[i++]=0
	}

	# print "pickv=" pickv " pickx=" pickx " picky=" picky

	if (pickv != 0) {
		board[w * picky + pickx]=pickv
	}

	# for (i=0; i < cells;) {
	# 	for (j=0; j < w; j++) printf("%d ", board[i++])
	# 	print ""
	# }

	j=0
	for (x=0; x < w; x++) {
		pop=0
		i=w - x - 1
		for (y=0; y < h; y++) {
			v=board[i]; i+=w
			if (v != 0) pop++
			tran[j++]=v
		}

		lpop[x]=pop
		lghost[x]=0
	}

	# for (i=0; i < cells;) {
	# 	printf("%d:", lpop[i / h])
	# 	for (j=0; j < h; j++) printf(" %d", tran[i++])
	# 	print ""
	# }

	return (0)
}

#  cwk:         clockwise key
#    k:                   key (no rotation)
# ccwk: counter clockwise key
#
#  the key for 180 rotation is implied
#
# w and h: current width and height
function direction(cwk, k, ccwk, w, h,   da) {
	# print ""
	# print "key=" key " k=" k " w=" w " h=" h

	if (key == k) {
		da=quickest(w, h)
	} else if (key == cwk) {
		da=cw(h, w)
	} else if (key == ccwk) {
		da=ccw(h, w)
	} else {
		da=quicker(w, h)
	}

	key=k
	# print da

	# If no syms moved around or merged, don't pick a new empty cell
	# for an additional symbol because then the game is too simple.
	if (merge(w, h) == 0) {
		if (da == 0) {
			pickv=0
			return (0)
		}
	}

	pickv=pick(w, h)

	# print "pickv=" pickv " pickx=" pickx " picky=" picky

	return (1)
}

function dow(   w, h, i, x, y, pop) {
	w=cols; h=rows
	direction(nkey, wkey, skey, w, h)

	col=pickx
	row=picky

	# print "col=" col " row=" row

	i=0
	for (y=0; y < h; y++) {
		pop=lpop[y]
		for (x=0; x < pop; x++) { board[i]=tran[i]; i++ }

		pop+=lghost[y]
		for (; x < pop; x++) board[i++]=-1

		for (; x < w; x++) board[i++]=0
	}

	draw()
}

function doe(   w, h, i, j, x, y, pop) {
	w=cols; h=rows
	direction(skey, ekey, nkey, w, h)

	col=w - pickx - 1
	row=h - picky - 1

	# print "col=" col " row=" row

	i=0
	j=cells - 1
	for (y=0; y < h; y++) {
		pop=lpop[y]
		for (x=0; x < pop; x++) board[j--]=tran[i++]

		pop+=lghost[y]
		for (; x < pop; x++) { board[j--]=-1; i++ }

		for (; x < w; x++) { board[j--]=0; i++ }
	}

	draw()
}

function don(   w, h, i, j, x, y, pop) {
	w=rows; h=cols
	direction(ekey, nkey, wkey, w, h)

	col=h - picky - 1
	row=pickx

	# print "col=" col " row=" row

	i=0
	for (x=0; x < h; x++) {
		j=h - x - 1

		pop=lpop[x]
		for (y=0; y < pop; y++) { board[j]=tran[i++]; j+=h }

		pop+=lghost[x]
		for (; y < pop; y++) { board[j]=-1; i++; j+=h }
		
		for (; y < w; y++) { board[j]=0; i++; j+=h }
	}

	draw()
}

function dos(   w, h, i, j, x, y, pop) {
	w=rows; h=cols
	direction(wkey, skey, ekey, w, h)

	col=picky
	row=w - pickx - 1

	# print "col=" col " row=" row

	i=0
	for (x=0; x < h; x++) {
		j=cells - h + x

		pop=lpop[x]
		for (y=0; y < pop; y++) { board[j]=tran[i++]; j-=h }

		pop+=lghost[x]
		for (; y < pop; y++) { board[j]=-1; i++; j-=h }

		for (; y < w; y++) { board[j]=0; i++; j-=h }
	}

	draw()
}

# tabs don't work well with the backspace style
# highlighting anyway, just ignore them
function findsp(start, n, len, dir,   k, m) {
	for (k=start; n-- > 0; k+=dir) {
		for (m=k; m <= len; m+=slen) {
			if (substr(hisyms, m, 1) != " ")
				return (k)
		}
	}

	return (k)
}

function init(   i, j, k, l, m, n) {
	errstat=0

	# if there was no seed provided, get one from the system time
	if (seed == "") {
		# returns 0, but picks one based on time
		srand()

		# what was it
		seed=srand()
	}

	srand(seed)

	# seems to help the early distribution on some old awks
	for (i=0; i<256; i+=1) rand();

	rows=int(rows)
	if ((rows + 0) !~ /^[1-9][0-9]?$/)
  errexit("rows must be a positive integer smaller than one-hundred: " rows)

	cols=int(cols)
	if ((cols + 0) !~ /^[1-9][0-9]?$/)
  errexit("cols must be a positive integer smaller than one-hundred: " cols)

	cells=rows * cols
	for (i=0; i < cells; i++) {
		board[i]=0
		tran[i]=0
	}

	for (i=0; i < rows; i++) { lpop[i]=0; lghost[i]=0 }

	# in case more cols than rows
	for (; i < cols; i++) { lpop[i]=0; lghost[i]=0 }

	# syms, hisyms, and losyms magic

	# the length of every cell when drawn is the length of the empty cell
	# representation
	slen=length(esym)

	i=length(syms)
	if (i % slen != 0)
  errexit("len(syms)=" i " must be a multiple of len(esym)=" slen)

	j=i / slen
	if (high > j) errexit("too few syms")

	# makes them the upper case of syms, don't like that, set hisyms or use
	# only uppercase anyway in syms like the default.
	if (hisyms == "") hisyms=toupper(syms)

	if (length(hisyms) != i)
  errexit("hisyms and syms must be equal in length")

	# figure-out how to highlight, don't like this way, create losysms how
	# you want, the syntrax is simple, imagine the output of /usr/bin/ul -i
	#
	#   if there is a space charater, that portion of hisyms will not be
	#   hilighted
	#
	#   if there is a - character, that portion of hisyms will be
	#   highlighted
	#
	# notice that regardless of highlighting (terminal escapes, nroff style)
	# the string from hisyms will always be used for a highlighted value -
	# in particular if the case of syms and hisyms differ, that will be
	# resopected in the output
	if (losyms == "") {
		# The idea is to find the minimum start and end that envelops
		# all characters that are not leading or trailing spaces, so for
		# example if the symbols were in hex:
		#
		# '  1'
		# '  2'
		# '  4'
		#  ...
		# ' 10'
		# ' 20'
		#
		# You would want losyms to be ' -- --' ... ' -- --'
		k = findsp(1, slen, i, 1)
		l = findsp(slen, slen - k, i, -1)

		# old awk does not have len params in sprintf to use and I'm 
		# not sure about the length between % and s, likely depends
		# on libc on the system if that is supported or not
		n=""
		for (m=1; m < k; m++) {
			n=n " "
		}

		for (;m <= l; m++) {
			n=n "-"
		}

		for (;m <= slen; m++) {
			n=n " "
		}

		losyms=""
		for (m=0; m < j; m++) losyms=losyms n
	}

	if (length(losyms) != i) 
  errexit("hisyms and syms must be equal in length")

	colors=split(colors, carr)

	free=cells
	won=0

	# if score and lscore differ, some syms have merged
	score=0
	lscore=0

	# I know this is gross, globals that pick() returns into
	pickx=0
	picky=0

	pickv=pick(cols, rows)

	# so the first line printed is all lower case directions
	key=ekey wkey skey nkey ekey wkey skey nkey

	# similarly ugly, draw uses these
	col=pickx
	row=picky

	# print syms
	# print hisyms
	# print losyms

	op=""

	if (of != "") {
		if (substr(of, 1, 1) == "|") {
			op=substr(of, 2)
			of=""
		}
	}

	# alternate screen may be inhibited, don't clear the first time
	i=cl
	cl=""

	# only draw it once
	j=vb
	vb=""

	# XXX: It would be really neat if I could use dow and doe here and
	#      have two syms appear just like the original version.
	draw()

	key=wkey

	# restore
	cl=i
	vb=j
}

# return zero only if there are more moves, only called during exit
function lost() {
	if (free != 0) return (0)

	op=""; of="/dev/null"

	dow()
	if (score != lscore) return (0)

	dos()
	if (score != lscore) return (0)

	return (1)
}

# argument processing
NR == 1 { init(); next }

# quit
tolower($0) == qkey { exit }

tolower($0) == wkey { dow() }

tolower($0) == ekey { doe() }

tolower($0) == nkey { don() }

tolower($0) == skey { dos() }

{ lscore=score }

END {
	if (errstat != 0) exit errstat

	oprint(carr[1])

	if (won != 0) {
		print  "congratulations" | "/bin/cat >&2"
		exit 0
	}
	
	if (lost() == 0) {
		print "thanks for playing" | "/bin/cat >&2"
	} else {
		print "please try again" | "/bin/cat >&2"
	}

	exit 1
}
