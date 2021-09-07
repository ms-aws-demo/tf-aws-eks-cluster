{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "AWS": [
            "${admin_trust_arn}",
            "${tf_trust_arn}",
            "${cyderes_trust_arn}"
          ]
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }