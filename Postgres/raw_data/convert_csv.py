import sys
import re

for line in sys.stdin:
    line.rstrip()
    outline = line.replace(b",",b"   ").replace(b"^",b",").replace(b"'",b"").replace(b"~","'").replace(b'"',b"in")
    print re.sub(b"'(\d+)'", b"\\1", outline).rstrip()


'''
#with open("bad_food.csv","rb") as bad_file:
        zero=bad_file.read().replace(b",",b"   ")
        one=zero.replace(b"^",b",")
        two=one.replace(b"'",b"")
        three=two.replace(b"~",b"'")
        four=three.replace(b'"',b"in")
        five=re.sub(b"'(\d+)'", b"\\1", four);
#        five=re.sub(b"^\'(\d+)\',\'(\d+)\',(.*)$", b"\1,\2,\3", four);
        #print(one)
        with open("new_desc.csv", "wb") as new_csv:
            new_csv.write(five)
'''
