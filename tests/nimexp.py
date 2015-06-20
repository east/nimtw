import network
import content

def buildEnum(prefix, enums, startVal=0, flags=False):
	print("  " + prefix + "* {.pure.} = enum")

	first = True

	count = 0
	for e in enums:
		enum = e
		
		#enum = enum.lower()
		#enum = enum[0].upper() + enum[1:]

		if first and startVal != 0 and not flags:
			print("    " + enum + "="+str(startVal)+",")
		elif flags:
			print("    " + enum + " = 1 shl "+str(count)+",")
		else:			
			print("    " + enum + ",")
		
		if first: first = False
		count += 1

	print()

def convWord(name, word):
	prev = name

	# remove _
	while name.find("_") != -1:
		offs = name.find("_")
		name = name[:offs] + name[offs+1].upper() + name[offs+2:]

	offs = name.lower().find(word)

	if offs == -1:
		# word not found
		return name

	if offs == 1:
		# ignore unlikely offs
		return name

	# upper first char of word
	name = name[:offs] + name[offs].upper() + name[offs+1:]

	if len(name) > offs+len(word):
		# also upper first char of next word
		offs = offs+len(word)
		if offs != len(name)-1:
			name = name[:offs] + name[offs].upper() + name[offs+1:] 

	#print(prev, "to", name)
	return name

# converting all uppercase to pascal case
def convertName(name):
	p = name[0].upper() + name[1:].lower()

	# exceptions
	# small wordlist to fix PascalCase
	wordList = ["info", "sound", "core", "tee", "state", "flag", "over", "death", "ind", "global", "hit", "dot", "jump", "ammo", "input", "data"]

	for w in wordList:
		p = convWord(p, w)

	return p 

def prepareEnums(enums):
	for i in range(0, len(enums)):
		enums[i] = convertName(enums[i])	

# build nim enums

# network
for e in network.Enums:
	name = e.name[0].upper() + e.name[1:].lower()

	prepareEnums(e.values)

	buildEnum(name, e.values)

# network flags
for e in network.Flags:
	name = convertName(e.name)

	prepareEnums(e.values)

	buildEnum(name, e.values, flags=True)

# net objects / events
objects = ["Invalid"]

for o in network.Objects:
	if o.enum_name.startswith("NETOBJTYPE_"):
		objects += ["Obj"+convertName(o.enum_name[11:])]
	elif o.enum_name.startswith("NETEVENTTYPE_"):

		objects += ["Evt"+convertName(o.enum_name[13:])]
	

buildEnum("NetObj", objects)

# sound
sounds = []
for s in content.container.sounds.items:
	sounds += [convertName(s.name.value)]

buildEnum("Sound", sounds)

# weapon
weapons = []
for w in content.container.weapons.id.items:
	weapons += [convertName(w.name.value)]

buildEnum("Weapon", weapons)
