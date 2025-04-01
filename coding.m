a = 1:10
sum(a)

b=[1 2 3 4 5]

c=[1 2 3 ;4 5 6;7 8 9]
size(c)
c'

eye(5)
zeros(5)
ones(5)
sqrt(16)

N=50
Y=randn(N,1)
Y2=randn(N,1)
t=linspace(0,0.1,N)
plot(t,Y)
hold on
plot(t,Y2)