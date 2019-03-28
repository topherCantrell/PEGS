// :x:V0:
CLUSTER 
V0=0
_if_1_1:
_if_1_expression:
_loop_1_start:
V0<10
BRANCH-IFNOT _if_1_false
_if_1_true:
print "HELLO WORLD!\n"
_loop_1_continue:
V0=V0+1
GOTO _loop_1_start
_loop_1_end:
_if_1_end:
_if_1_false:
STOP
--DATA--
_msg_6:
"HELLO WORLD!\n",0
