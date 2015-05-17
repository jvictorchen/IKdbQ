\d .json

/[]{} Cbg*xhijefcspmdznuvt
q:"\""
s:{q,x,q}
t:{s$[#x;@[x;4,$[7<#x;7;!0];:;"-"];x]}
J:(($`0`1)!$`false`true;s;{$[#x;x;"null"]};s;t;s)1 2 5 10 12 16h bin

/enclose
e:{(*x),(","/:y),*|x}
j:{$[10=abs t:@x;s@,/{$[x in r:"\t\n\r\"\\";"\\","tnr\"\\"r?x;x]}'x;99=t;e["{}"](j'!x),'":",'j'. x;-1<t;e["[]"]@j'x;J[-t]@$x]}

/dsclose
v:=\~q=
d:{$[2<#x;1_'(0,&(v[x]&","=x)&1=+\1 -1 1 -1"{}[]"?x)_-1_x;()]}
c:{$["{"=*x;!/+{(`$c n#x;c(1+n:x?":")_x)}'d x;"["=*x;c'd x;q=*x;1_-1_x;"a">*x;. x;"n"=*x;0N;"t"=*x]}
k:{c x@&~v[x]&^x:p x}
p:{r:"";i:0; while[i<#x;r,:$[m:"\\"=x i;{$[x in r:"\\nrt\"";"\\\n\r\t\"" r?x;"\\",x]}x i+1;x i];i+:$[m;2;1]];:r}

\
