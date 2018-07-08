Rebol [
	notes: {send a task to 8th, and have the result as JSON}
	title: "Test Kashflow"
	file: %test-kashflow.r2 
	date: 13-June-2018
]

User: none ; "drgchiu"
Pass: none ; 	

if not exists? %altjson.r [
	write %altjson.r read https://raw.githubusercontent.com/rgchris/Scripts-For-Rebol-2/master/altjson.r
]
do %altjson.r
do %zmq-load.r
ctx: zmq-ctx-new

; the socket that sends jobs to 0MQ
sender: zmq-socket ctx zmq_push
; since is going to serve jobs for workers to pull from it will be a server
zmq-bind sender "tcp://*:5557"

; the socket the workers connect to send results
receiver: zmq-socket ctx zmq_pull ;zmq-constants/pull
zmq-bind receiver "tcp://*:5558"

text-styles: stylize [
	lab: label 100 blue
]

lay: layout [
	styles text-styles
	across
	t: h1 red black (to string! now/time) rate 1 feel [engage: [t/text: now/time show t update-details check-response]] return
	lab "UserID" userfld: field "drgchiu" return
	lab "Password" passfld: field hide return
	bar 310 return
	lab "Customer ID:" custfld: field 40 [cus: copy value] 
	; button "clear" [clear-fields] 
	return
	bar 310 return
	lab "Name:" namefld: field return
	lab "PhoneNo:" phonefld: field return
	lab "Address1:" add1fld: field return
	lab "Address2:" add2fld: field return
	lab "Address3:" add3fld: field return
	bar 310 return
	lab "Status" statusfld: field return
	button "Halt" [ unview/all halt ]
	button "Print" [ print "testing" ]
	button "Web" [ print read http://www.rebol.com ] return
	do [focus custfld]
]

Cus: none

digits: charset "0123456789"

; create a JSON string to send as a task
create-job: func [CustomerCode /local job][
	job: make object! compose [
		UserName: (user)
		Password: (pass)
		CustomerCode: (CustomerCode)
		api: "GetCustomer"
	]
	to-JSON job
]

clear-fields: does [
	cus: none
	foreach f reduce [namefld phonefld add1fld add2fld add3fld custfld statusfld][clear-face f]
	focus custfld
]

update-details: has [CustomerCode] [
	; every second we check to see if the cus is not none and if it's a number, then send a request to server to see who it is
	if all [
		cus
		not empty? cus
		parse cus [some digits]
		not empty? user: get-face userfld
		not empty? pass: passfld/data
	][
		CustomerCode: copy cus
		clear-fields
		set-face statusfld "calling 8th"
		res: z-send-msg sender msg: create-job CustomerCode
	]
]

check-response: has [result r][
	if string: z-recv-msg/dont-wait/max-size receiver 10'000 [
		attempt [
			result: load-json string
			status: result/children/1/children/1/children/3
			r: result/children/1/children/1/children/1/children ; list of object
			foreach object r [
				case [
					object/tag = "Name" [set-face namefld object/data]
					object/tag = "Mobile" [set-face phonefld object/data]
					object/tag = "Address1" [set-face add1fld object/data]
					object/tag = "Address3" [set-face add2fld object/data]
					object/tag = "Address4" [set-face add3fld object/data]
				]
			]
			set-face statusfld "OK"
		]
		attempt [
			if status/tag = "StatusDetail" [
				if none? result: get in status 'data [
					result: copy "OK"
				]
				set-face statusfld result
			]
		]

	]
]

view lay

zmq-close sender
zmq-close receiver
zmq-ctx-term ctx
; so we can see the console
halt 
