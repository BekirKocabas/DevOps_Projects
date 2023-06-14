#! /bin/bash
yum update -y
yum install python3 -y
pip3 install flask
pip3 install flask_mysql
yum install git -y
TOKEN="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" #your github token
cd /home/ec2-user && git clone https://$TOKEN@github.com/BekirKocabas/phonebook
python3 /home/ec2-user/phonebook/phonebook-app.py