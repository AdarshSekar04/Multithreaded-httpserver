#!/usr/bin/env bash
#./httpserver 8080 -l test.server.log &

start_server() {
    ./httpserver 8080 -l server.log &
    sleep 5s
}

test_one() {
    start_server
    printf "Testing single GET\n"
    curl -s localhost:8080/Makefile > test.get.out
    diff Makefile test.get.out
    pkill httpserver
}

test_two() {
    printf "Testing single PUT\n"
    start_server
    curl -s -T DESIGN.pdf localhost:8080/design_put_out
    diff DESIGN.pdf design_put_out
    pkill httpserver
}

test_three() {
    printf "Testing single valid request with logging enabled\n"
    size=$(stat -c%s Makefile)
    printf "GET /Makefile length $size\n" > test.three.expectedlog.out
    python3 hex.py Makefile >> test.three.expectedlog.out
    printf "========\n" >> test.three.expectedlog.out
    start_server
    curl -s localhost:8080/Makefile > test.getlog.out
    # awk 'NR>2 {print last} {last=$0}' < server.log | tee test.getlog.o.hex &>1 > /dev/null
    # diff test.getlog.e.hex test.getlog.o.hex
    diff test.three.expectedlog.out server.log
    pkill httpserver
}

test_four() {
    printf "Testing valid GET request on small binary file with logging enabled\n"
    head -c 200 /dev/urandom > test_in_bin
    size=$(stat -c%s test_in_bin)
    printf "GET /test_in_bin length $size\n" > test.four.expectedlog.bin.out
    python3 hex.py test_in_bin >> test.four.expectedlog.bin.out
    printf "========\n" >> test.four.expectedlog.bin.out
    start_server
    curl -s localhost:8080/test_in_bin > test.getlogbin.out
    sleep 0.1
    diff test_in_bin test.getlogbin.out
    diff test.four.expectedlog.bin.out server.log
    # awk 'NR>2 {print last} {last=$0}' < server.log | tee test.getlogbin.o.hex &>1 > /dev/null
    # diff test.getlogbin.e.out test.getlogbin.o.hex
    pkill httpserver
}

test_five() {
    printf "Testing valid GET request on large binary file with logging enabled\n"
    head -c 20000 /dev/urandom > test_in_bin
    size=$(stat -c%s test_in_bin)
    printf "GET /test_in_bin length $size\n" > test.five.expectedlog.bin.out
    python3 hex.py test_in_bin >> test.five.expectedlog.bin.out
    printf "========\n" >> test.five.expectedlog.bin.out
    start_server
    curl -s localhost:8080/test_in_bin > test.getlogbin.out
    sleep 0.5
    # awk 'NR>2 {print last} {last=$0}' < server.log | tee test.getlogbin.o.hex &>1 > /dev/null
    diff test.getlogbin.out test_in_bin
    diff test.five.expectedlog.bin.out server.log
    pkill httpserver
}

test_six() {
    printf "Testing concurrent GET with logging disabled\n"
    ./httpserver 8080
    curl -s -o cget1.out localhost:8080/design_put_out &\
    curl -s -o cget2.out localhost:8080/design_put_out &\
    curl -s -o cget3.out localhost:8080/design_put_out &\
    curl -s -o cget4.out localhost:8080/design_put_out &\
    curl -s -o cget5.out localhost:8080/design_put_out &\
    curl -s -o cget6.out localhost:8080/design_put_out &\
    sleep 0.5
    diff DESIGN.pdf cget1.out
    diff DESIGN.pdf cget2.out
    diff DESIGN.pdf cget3.out
    diff DESIGN.pdf cget4.out
    diff DESIGN.pdf cget5.out
    diff DESIGN.pdf cget6.out
    pkill httpserver
}

test_seven() {
    printf "Testing concurrent GET request with logging enabled\n"
    head -c 200 /dev/urandom > test_file1
    head -c 200 /dev/urandom > test_file2
    size1=$(stat -c%s test_file1)
    size2=$(stat -c%s test_file2)
    printf "GET /test_file1 length $size1\n" > test.seven.expectedlog1.out
    python3 hex.py test_file1 >> test.seven.expectedlog1.out
    printf "========\n" >> test.seven.expectedlog1.out
    sed '$d' test.seven.expectedlog1.out > test.seven.expectedlog1.out
    printf "GET /test_file2 length $size2\n" > test.seven.expectedlog2.out
    python3 hex.py test_file2 >> test.seven.expectedlog2.out
    printf "========\n" >> test.seven.expectedlog2.out
    sed '$d' test.seven.expectedlog2.out > test.seven.expectedlog2.out
    start_server
    curl -s localhost:8080/test_file1 > test_file1.out &\
    # curl -s localhost:8080/blah &\
    curl -s localhost:8080/test_file2 > test_file2.out &
    sleep 0.5
    diff test_file1 test_file1.out
    diff test_file2 test_file2.out
    python3 -c "x=open('server.log').read(); y=open('test.seven.expectedlog1.out').read(); print('TEST 1:', 'PASS' if y in x else 'FAIL')"
    python3 -c "x=open('server.log').read(); y=open('test.seven.expectedlog2.out').read(); print('TEST 2:', 'PASS' if y in x else 'FAIL')"
    pkill httpserver
    rm test_file1 test_file2 test.seven.expectedlog*.out test_file*.out
}

test_eight() {
    printf "Testing concurrent requests including at least one 400 with logging enabled\n"
    head -c 200 /dev/urandom > test_file1
    head -c 200 /dev/urandom > test_file2
    size1=$(stat -c%s test_file1)
    size2=$(stat -c%s test_file2)
    # printf "GET /Makefile length $size1\n" > test.eight.expectedlog1.out
    printf "GET /test_file1 length $size1\n" > test.eight.expectedlog1.out
    python3 hex.py test_file1 >> test.eight.expectedlog1.out
    printf "========\n" >> test.eight.expectedlog1.out
    sed '$d' test.eight.expectedlog1.out > test.eight.expectedlog1.out
    # printf "GET /Makefile length $size1\n" > test.eight.expectedlog2.out
    printf "GET /test_file2 length $size2\n" > test.eight.expectedlog2.out
    python3 hex.py test_file2 >> test.eight.expectedlog2.out
    printf "========\n" >> test.eight.expectedlog2.out
    sed '$d' test.eight.expectedlog2.out > test.eight.expectedlog2.out
    printf "FAIL: GET /bl.ah HTTP/1.1 --- response 400\n========\n" > test.eight.expectedlog3.out
    printf "FAIL: GET /$ HTTP/1.1 --- response 400\n========\n" > test.eight.expectedlog4.out
    printf "FAIL: GET /this_shoudbe+ HTTP/1.1 --- response 400\n========\n" > test.eight.expectedlog5.out
    printf "HEAD /test_file2 length $size2\n========\n" > test.eight.expectedlog6.out
    printf "FAIL: POST /something HTTP/1.1 --- response 400\n========\n" > test.eight.expectedlog7.out
    printf "FAIL: DELETE /Makefile HTTP/1.1 --- response 400\n========\n" > test.eight.expectedlog8.out
    printf "FAIL: GET /SADKJLKASJKLDJALSDJKLASJDLKAJDLKSJKLDJLKAJSDKDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDhello HTTP/1.1 --- response 400\n========\n" > test.eight.expectedlog9.out
    start_server
    curl -s localhost:8080/this_shoudbe+ &\
    printf "DELETE /Makefile HTTP/1.1\r\nContent-Length: 0\r\n\r\n" | nc localhost 8080 &\
    curl -s localhost:8080/test_file1 > test_file1.out &\
    curl -s localhost:8080/bl.ah &\
    printf "POST /something HTTP/1.1\r\nContent-Length: 0\r\n\r\n" | nc localhost 8080 &\
    curl -s localhost:8080/test_file2 > test_file2.out &\
    printf "GET /SADKJLKASJKLDJALSDJKLASJDLKAJDLKSJKLDJLKAJSDKDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDhello HTTP/1.1\r\nContent-Length: 0\r\n\r\n" | nc localhost 8080 &\
    curl -s localhost:8080/\$ &\
    curl -s -I localhost:8080/test_file2 &
    sleep 0.5
    diff test_file1 test_file1.out
    diff test_file2 test_file2.out
    python3 -c "x=open('server.log').read(); y=open('test.eight.expectedlog1.out').read(); print('TEST 1:', 'PASS' if y in x else 'FAIL')"
    python3 -c "x=open('server.log').read(); y=open('test.eight.expectedlog2.out').read(); print('TEST 2:', 'PASS' if y in x else 'FAIL')"
    python3 -c "x=open('server.log').read(); y=open('test.eight.expectedlog3.out').read(); print('TEST 3:', 'PASS' if y in x else 'FAIL')"
    python3 -c "x=open('server.log').read(); y=open('test.eight.expectedlog4.out').read(); print('TEST 4:', 'PASS' if y in x else 'FAIL')"
    python3 -c "x=open('server.log').read(); y=open('test.eight.expectedlog5.out').read(); print('TEST 5:', 'PASS' if y in x else 'FAIL')"
    python3 -c "x=open('server.log').read(); y=open('test.eight.expectedlog6.out').read(); print('TEST 6:', 'PASS' if y in x else 'FAIL')"
    python3 -c "x=open('server.log').read(); y=open('test.eight.expectedlog7.out').read(); print('TEST 7:', 'PASS' if y in x else 'FAIL')"
    python3 -c "x=open('server.log').read(); y=open('test.eight.expectedlog8.out').read(); print('TEST 8:', 'PASS' if y in x else 'FAIL')"
    python3 -c "x=open('server.log').read(); y=open('test.eight.expectedlog9.out').read(); print('TEST 9:', 'PASS' if y in x else 'FAIL')"
    pkill httpserver
    rm test_file1 test_file2 test.eight.expectedlog*.out test_file*.out
}

test_nine() {
    printf "Testing concurrent requests including at least one 400/404 with logging enabled\n"
    head -c 200 /dev/urandom > test_file1
    head -c 200 /dev/urandom > test_file2
    size1=$(stat -c%s test_file1)
    size2=$(stat -c%s test_file2)
    printf "GET /test_file1 length $size1\n" > test.nine.expectedlog1.out
    python3 hex.py test_file1 >> test.nine.expectedlog1.out
    printf "========\n" >> test.nine.expectedlog1.out
    sed '$d' test.nine.expectedlog1.out > test.nine.expectedlog1.out
    printf "GET /test_file2 length $size2\n" > test.nine.expectedlog2.out
    python3 hex.py test_file2 >> test.nine.expectedlog2.out
    printf "========\n" >> test.nine.expectedlog2.out
    sed '$d' test.nine.expectedlog2.out > test.nine.expectedlog2.out
    printf "FAIL: GET /bl.ah HTTP/1.1 --- response 400\n========\n" > test.nine.expectedlog3.out
    printf "FAIL: GET /$ HTTP/1.1 --- response 400\n========\n" > test.nine.expectedlog4.out
    printf "FAIL: GET /this_shoudbe+ HTTP/1.1 --- response 400\n========\n" > test.nine.expectedlog5.out
    printf "HEAD /test_file2 length $size2\n========\n" > test.nine.expectedlog6.out
    printf "FAIL: POST /something HTTP/1.1 --- response 400\n========\n" > test.nine.expectedlog7.out
    printf "FAIL: DELETE /Makefile HTTP/1.1 --- response 400\n========\n" > test.nine.expectedlog8.out
    printf "FAIL: GET /SADKJLKASJKLDJALSDJKLASJDLKAJDLKSJKLDJLKAJSDKDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDhello HTTP/1.1 --- response 400\n========\n" > test.nine.expectedlog9.out
    printf "FAIL: GET /test_file3 HTTP/1.1 --- response 404\n========\n" > test.nine.expectedlog10.out
    printf "FAIL: HEAD /test_file11 HTTP/1.1 --- response 404\n========\n" > test.nine.expectedlog11.out
    start_server
    curl -s localhost:8080/this_shoudbe+ &\
    printf "DELETE /Makefile HTTP/1.1\r\nContent-Length: 0\r\n\r\n" | nc localhost 8080 &\
    curl -s localhost:8080/test_file1 > test_file1.out &\
    curl -s -I localhost:8080/test_file11 &\
    curl -s localhost:8080/bl.ah &\
    curl -s localhost:8080/test_file3 &\
    printf "POST /something HTTP/1.1\r\nContent-Length: 0\r\n\r\n" | nc localhost 8080 &\
    curl -s localhost:8080/test_file2 > test_file2.out &\
    printf "GET /SADKJLKASJKLDJALSDJKLASJDLKAJDLKSJKLDJLKAJSDKDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDhello HTTP/1.1\r\nContent-Length: 0\r\n\r\n" | nc localhost 8080 &\
    curl -s localhost:8080/\$ &\
    curl -s -I localhost:8080/test_file2 &
    sleep 0.5
    diff test_file1 test_file1.out
    diff test_file2 test_file2.out
    python3 -c "x=open('server.log').read(); y=open('test.nine.expectedlog1.out').read(); print('TEST 1:', 'PASS' if y in x else 'FAIL')"
    python3 -c "x=open('server.log').read(); y=open('test.nine.expectedlog2.out').read(); print('TEST 2:', 'PASS' if y in x else 'FAIL')"
    python3 -c "x=open('server.log').read(); y=open('test.nine.expectedlog3.out').read(); print('TEST 3:', 'PASS' if y in x else 'FAIL')"
    python3 -c "x=open('server.log').read(); y=open('test.nine.expectedlog4.out').read(); print('TEST 4:', 'PASS' if y in x else 'FAIL')"
    python3 -c "x=open('server.log').read(); y=open('test.nine.expectedlog5.out').read(); print('TEST 5:', 'PASS' if y in x else 'FAIL')"
    python3 -c "x=open('server.log').read(); y=open('test.nine.expectedlog6.out').read(); print('TEST 6:', 'PASS' if y in x else 'FAIL')"
    python3 -c "x=open('server.log').read(); y=open('test.nine.expectedlog7.out').read(); print('TEST 7:', 'PASS' if y in x else 'FAIL')"
    python3 -c "x=open('server.log').read(); y=open('test.nine.expectedlog8.out').read(); print('TEST 8:', 'PASS' if y in x else 'FAIL')"
    python3 -c "x=open('server.log').read(); y=open('test.nine.expectedlog9.out').read(); print('TEST 9:', 'PASS' if y in x else 'FAIL')"
    python3 -c "x=open('server.log').read(); y=open('test.nine.expectedlog10.out').read(); print('TEST 10:', 'PASS' if y in x else 'FAIL')"
    python3 -c "x=open('server.log').read(); y=open('test.nine.expectedlog11.out').read(); print('TEST 11:', 'PASS' if y in x else 'FAIL')"
    pkill httpserver
    rm test_file1 test_file2 test.nine.expectedlog*.out test_file*.out
}

# test_five() {
#     printf "Testing invalid healthcheck (403)"
#     start_server
#     printf "1\n10" > healthcheck.403.out
#     curl -s -I localhost:8080/healthcheck
#     curl -s -o chc.403.out localhost:8080/healthcheck
#     diff healthcheck.403.out chc.403.out
#     pkill httpserver
# }

clean() {
    printf "Cleaning..\n"
    rm -f test.* test_* design_put_out cget*.out healthcheck.403.out chc.403.out test.server.log
}

test_main() {
    test_seven
    sleep 0.1

    test_eight
    sleep 0.1

    test_nine
    sleep 0.1
    clean
}

# test_one
# sleep 0.5

# test_two
# sleep 0.5

# test_five
# test_nine
# sleep 0.5

# sleep 0.5
# clean

test_main

# printf "Testing valid healthcheck"

# printf "Sending parallel curl requests to server\n"
# curl -s localhost:8080/Makefile > f1 &\
# curl -s localhost:8080/Makefile > f2 &\
# curl -s localhost:8080/Makefile > f3 &\
# curl -s localhost:8080/Makefile > f4

# sleep 0.5s

# printf "diff Makefile f1\n"
# diff Makefile f1 --color

# printf "diff Makefile f2\n"
# diff Makefile f2 --color

# printf "diff Makefile f3\n"
# diff Makefile f3 --color

# printf "diff Makefile f4\n"
# diff Makefile f4 --color

# rm -f f1 f2 f3 f4

# printf "Test concurrent HEAD\n"
# curl -I -s localhost:8080/Makefile &\
# curl -I -s localhost:8080/Makefile &\
# curl -I -s localhost:8080/Makefile &\
# curl -I -s localhost:8080/Makefile

# sleep 0.5s

# printf "Test num_clients > num_workers\n"
# curl -s localhost:8080/Makefile > f1 &\
# curl -s localhost:8080/Makefile > f2 &\
# curl -s localhost:8080/Makefile > f3 &\
# curl -s localhost:8080/Makefile > f4 &\
# curl -s localhost:8080/Makefile > f5 &\
# curl -s localhost:8080/Makefile > f6 &\
# curl -s localhost:8080/Makefile > f7 &\
# curl -s localhost:8080/Makefile > f8

# sleep 0.5s

# printf "diff Makefile f1\n"
# diff Makefile f1 --color

# printf "diff Makefile f2\n"
# diff Makefile f2 --color

# printf "diff Makefile f3\n"
# diff Makefile f3 --color

# printf "diff Makefile f4\n"
# diff Makefile f4 --color

# printf "diff Makefile f5\n"
# diff Makefile f5 --color

# printf "diff Makefile f6\n"
# diff Makefile f6 --color

# printf "diff Makefile f7\n"
# diff Makefile f7 --color

# printf "diff Makefile f8\n"
# diff Makefile f8 --color

# rm -f f1 f2 f3 f4 f5 f6 f7 f8

# printf "Test concurrent PUT\n"
# curl -s -T DESIGN.pdf localhost:8080/test_file1 &\
# curl -s -T DESIGN.pdf localhost:8080/test_file2 &\
# curl -s -T DESIGN.pdf localhost:8080/test_file3 &\
# curl -s -T DESIGN.pdf localhost:8080/test_file4

# sleep 0.5s

# printf "diff DESIGN.pdf test_file1\n"
# diff DESIGN.pdf test_file1 --color

# printf "diff DESIGN.pdf test_file2\n"
# diff DESIGN.pdf test_file2 --color

# printf "diff DESIGN.pdf test_file3\n"
# diff DESIGN.pdf test_file3 --color

# printf "diff DESIGN.pdf test_file4\n"
# diff DESIGN.pdf test_file4 --color

# # sleep 10s

# # rm -f test_file1 test_file2 test_file3 test_file4

# # printf "Stress Server\n"
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile &\
# # curl -s -o /dev/null localhost:8080/Makefile
