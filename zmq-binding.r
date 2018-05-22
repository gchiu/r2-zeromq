REBOL [
	Title:		"ZeroMQ Binding"
	Author:		"Kaj de Vos"
	Rights:		"Copyright (c) 2011 Kaj de Vos. All rights reserved."
	License: {
		Redistribution and use in source and binary forms, with or without modification,
		are permitted provided that the following conditions are met:

		    * Redistributions of source code must retain the above copyright notice,
		      this list of conditions and the following disclaimer.
		    * Redistributions in binary form must reproduce the above copyright notice,
		      this list of conditions and the following disclaimer in the documentation
		      and/or other materials provided with the distribution.

		THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
		ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
		WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
		DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
		FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
		DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
		SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
		CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
		OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
		OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
	}
	Needs:		"0MQ >= 2.0.7"
	Notes:		"Switch the zmq_init call in the new-pool routine for 0MQ <= 2.0.6"
]


context [
	binary: make struct! [value [binary!]] none
	pointer: make struct! [address [long]] none

	set 'address-of func [series [series!]] [
		binary/value: series
		change  third pointer  third binary

		binary/value: none  ; Don't block recycling
		pointer/address
	]
]


; C library

c-library: load/library either windows?: system/version/4 = 3 [%msvcrt.dll] [%libc.so.6]

copy-memory: make routine! ["Copy memory block."
	target	[long]
	source	[long]
	size	[long]
;	return:	[long]
] c-library "memcpy"


; 0MQ interface

zmq: load/library join %libzmq.  either windows? [%dll] [%so]

zmq: context [
	version: make routine! ["Return 0MQ version."
		major		[struct! [value [integer!]]]
		minor		[struct! [value [integer!]]]
		patch		[struct! [value [integer!]]]
	] zmq "zmq_version"

	new-pool: make routine! ["Return context handle."
;		app-threads	[integer!]  ; For 0MQ <= 2.0.6
		io-threads	[integer!]
;		flags		[integer!]  ; For 0MQ <= 2.0.6
		return: 	[long]
	] zmq "zmq_init"
	poll: 1
	end-pool: make routine! ["Clean up context."
		pool		[long]
		return: 	[integer!]
	] zmq "zmq_term"

	open: make routine! ["Open a socket."
		pool		[long]
		type		[integer!]
		return: 	[long]
	] zmq "zmq_socket"
	pair:				0
	publish:				1
	subscribe:			2
	request:					3
	reply:						4
	extended-request:	5
	extended-reply:		6
	push:				7
	pull:				8
	close: make routine! ["Clean up a socket from a context."
		socket		[long]
		return: 	[integer!]
	] zmq "zmq_close"

	; For 0MQ > 2.0.6:
	option: make routine! ["Get socket option."
		socket		[long]
		name		[integer!]
		value		[binary!]  ; Currently max 255 bytes
		size		[struct! [value [integer!]]]
		return: 	[integer!]
	] zmq "zmq_getsockopt"
	max-messages:		1
;	min-messages:		2
	swap-size:			3
	io-affinity:		4
	identity:			5
	max-rate:			8
	recovery-interval:	9
	loop-back?:			10
	send-buffer:		11
	receive-buffer:		12
	set: make routine! ["Set socket option."
		socket		[long]
		name		[integer!]
		value		[binary!]
		size		[integer!]
		return: 	[integer!]
	] zmq "zmq_setsockopt"
	filter:				6
	unsubscribe:		7

	serve: make routine! ["Set up server socket binding."
		socket		[long]
		end-point	[url!]
		return: 	[integer!]
	] zmq "zmq_bind"
	connect: make routine! ["Connect to a server socket."
		socket		[long]
		destination	[url!]
		return: 	[integer!]
	] zmq "zmq_connect"

	new-message: make routine! ["Create new message."
		message		[binary!]
		size		[long]
		return: 	[integer!]
	] zmq "zmq_msg_init_size"
	clear-message: make routine! ["Initialize new message."
		message		[binary!]
		return: 	[integer!]
	] zmq "zmq_msg_init"
	as-message: make routine! ["Convert to new message."
		message		[binary!]
		data		[binary!]
		size		[long]
		free		[long]
		hint		[long]
		return: 	[integer!]
	] zmq "zmq_msg_init_data"
	end-message: make routine! ["Clean up message."
		message		[binary!]
		return: 	[integer!]
	] zmq "zmq_msg_close"

	message-data: make routine! ["Return message data pointer."
		message		[binary!]
		return:		[long]
	] zmq "zmq_msg_data"
	message-size: make routine! ["Return message data size."
		message		[binary!]
		return: 	[long]
	] zmq "zmq_msg_size"

	send-message: make routine! ["Send message."
		socket		[long]
		message		[binary!]
		flags		[integer!]
		return: 	[integer!]
	] zmq "zmq_send"
	no-block: 1
	receive-message: make routine! ["Receive a message."
		socket		[long]
		message		[binary!]
		flags		[integer!]
		return: 	[integer!]
	] zmq "zmq_recv"

	copy-message: make routine! ["Copy message content to another message."
		target		[binary!]
		source		[binary!]
		return: 	[integer!]
	] zmq "zmq_msg_copy"
	move-message: make routine! ["Move message content to another message."
		target		[binary!]
		source		[binary!]
		return: 	[integer!]
	] zmq "zmq_msg_move"

	wait: make routine! ["Wait for selected events or timeout."
		events		[binary!]
		length		[integer!]
		timeout		[long]
		return: 	[integer!]
	] zmq "zmq_poll"
	poll-in:			1
	poll-out:		2
	poll-error:		4

	error: make routine! ["Return last status."
		return: 	[integer!]
	] zmq "zmq_errno"
	error-message: make routine! ["Return status message."
		code		[integer!]
		return:		[string!]
	] zmq "zmq_strerror"


	; Higher level interface

	message: head insert/dup  copy #{}  #{00} 42  ; Hopefully 0MQ isn't compiled to use larger Very Small Messages

	send: func [  ; Send message.
		socket		[integer!]
		data		[binary!]
		flags		[integer!]
	][
		either zero? as-message message data  length? data  0 0 [
			either zero? send-message socket message flags [
				zero? end-message message
			][
				end-message message
				no
			]
		][
			no
		]
	]

	receive: funct [  ; Receive a message.
		socket		[integer!]
		data		[binary!]
		flags		[integer!]
	][
		either zero? clear-message message [
			either zero? receive-message socket message flags [
				source: message-data message
				size: message-size message

				either size > length? data [
					insert/dup  tail data  #{00}  size - length? data
				][
					clear skip data size
				]
				copy-memory  address-of data  source size

				zero? end-message message
			][
				end-message message
				no
			]
		][
			no
		]
	]
]
