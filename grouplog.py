from bs4 import BeautifulSoup
import sys

if len(sys.argv)<=1:
	print "Usage: " + __file__ + " arg1 [arg2 [...]]\n"
	exit

def steam3ID264 ( id3 ):
# https://developer.valvesoftware.com/wiki/SteamID
# assuming public universe and an "individual" type account:
 return str(1 << 52 | 1 << 56 | 1 << 32 | id3)

def parsehistory( soup ):
	result = []
	
	group = soup.find('a',{'class':['groupadmin_header_name','hoverunderline']}).get('href').rpartition('/')[2]
	for event in soup.findAll("div",{'class':['historyItem','historyItemB']}):
		type = event.find('span','historyShort').contents[0]
		date = event.find('span','historyDate').contents[0]
		try:
			who = event.find('a',{'class':'whiteLink'})['data-miniprofile']
			who64 = steam3ID264(long(who))
		except IndexError:
			who="-"
			who64="-"
		try:
			actor = event.findAll('a',{'class':'whiteLink'})[1]['data-miniprofile']
			actor64 = steam3ID264(long(actor))
		except IndexError:
			actor = "-"
			actor64 = "-"
		
		who = "-" if who=="-" else "[U:1:{}]".format(who)
		actor = "-" if actor=="-" else "[U:1:{}]".format(actor)
		print "{};{};{};{};{};{};{}".format(type,date,who,who64,actor,actor64,group)
	return []
	
data=[]
print "event;time;user;user_id64;actor;actor_id64;group"
for fh in sys.argv[1:]:
	soup = BeautifulSoup(open(fh,'r'))
	data = data + parsehistory(soup)

