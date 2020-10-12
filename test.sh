curl -s -T dog http://localhost:$1/dog&
curl -s -I dog http://localhost:$1/dog&
curl -s dog http://localhost:$1/dog&

curl -s -T test_file http://localhost:$1/test&
curl -s test_file http://localhost:$1/test&
curl -s -I test_file http://localhost:$1/test&

curl -s -T TRIAL http://localhost:$1/TRIAL&
curl -s -I TRIAL http://localhost:$1/TRIAL&
curl -s TRIAL http://localhost:$1/TRIAL
