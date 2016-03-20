from bs4 import BeautifulSoup
import sys

if len(sys.argv)<=1:
	print "Usage: " + 	__file__ + " arg1 [arg2 [...]]\n"
	exit

def Steam3ID264 ( id3 ):
# https://developer.valvesoftware.com/wiki/SteamID
 return 76561197960265728 + id3

def parsehistory( soup ):
	result = []
	for event in soup.findAll("div",{'class':['historyItem','historyItemB']}):
		type = event.find('span','historyShort').contents[0]
		date = event.find('span','historyDate').contents[0]
		who = event.find('a',{'class':'whiteLink'})['data-miniprofile']
		try:
			actor = event.findAll('a',{'class':'whiteLink'})[1]['data-miniprofile']
		except IndexError:
			actor = "-"
		who = "[U:1:{}]".format(who)
		actor = "-" if actor=="-" else "[U:1:{}]".format(actor)
		print "{};{};{};{}".format(type,date,who,actor)
	return []
	
data=[]
print "event;time;Steam3ID;actor"
for fh in sys.argv[1:]:
	soup = BeautifulSoup(open(fh,'r'))
	data = data + parsehistory(soup)

