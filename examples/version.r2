REBOL [
    title:  "Report 0MQ version"
    author: "Gregg Irwin"
    email:  gregg_a_pointillistic_*_com
]

do %zmq-helpers.r2

print "Report 0MQ version"

print zmq-version

halt