Rebol [
	file: %taskventsink.r2
	name: "Graham"
	notes: {tested on 0mq 3.2, and based on the taskvent and tasksink scripts by Gregg.
		- start the work first eg. view -s taskwork.r2
		- then start this script eg. view -s taskventsink.r2

		This script then generates 100 random numbers as strings, and sends to 0MQ.
		The worker picks these up from 0MQ and squares the numbers, and sends it back to 0MQ
		This script then checks for a result.
		After 100 results it halts

		It assumes that jobs are returned in the same sequence they are sent but that may not be true if there are more 
		than one client.  It does test to see if the result returned is correct.
	}
	date: 7-June-2018
]


do %zmq-load.r

print "TaskVent and Sink"

ctx: zmq-ctx-new

; the socket that sends jobs to 0MQ
sender: zmq-socket ctx zmq_push
; since is going to serve jobs for workers to pull from it will be a server
zmq-bind sender "tcp://*:5557"

; the socket the workers connect to send results
receiver: zmq-socket ctx zmq_pull ;zmq-constants/pull
zmq-bind receiver "tcp://*:5558"

; This next isn't necessary. The jobs should be held in 0MQ's internal queues
ask "Press Enter when the workers are ready."

; let's generate a block of random numbers and send it to the workers
random/seed now/precise

tasks: copy []
results: copy []
n: 100
loop n [append tasks form random 100]


print "Sending tasks to workers..."

; now pickup the result by polling

-- n
forever [
	print ["now: " now/precise ]
	if not tail? tasks [
		res: z-send-msg sender msg: take tasks
		print ["Sent: " msg]
		append results msg
		?? res
	]
	if string: z-recv-msg/dont-wait receiver [
		string: to integer! string
		print ["square of " msg: to integer! take results " is: " string]
		if string <> (msg * msg) [
			print "Result received out of sequence"
		]
		if zero? -- n [break]
	]
	?? n
	wait 1
]

zmq-close sender
zmq-close receiver
zmq-ctx-term ctx
; so we can see the console
halt 
