{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "AWS": "${trust_arn}"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }