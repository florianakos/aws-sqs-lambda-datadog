#!/bin/bash
echo "Installing datadog dependency"
pip install --target ./package datadog
cd package

echo "Zipping Metric Submit lambda"
zip -r9 ${OLDPWD}/ddg_metric_submit.zip .
cd $OLDPWD
zip -g ddg_metric_submit.zip ddg_metric_submit.py

echo "Zipping Mock Data Source lambda"
zip ddg_mock_datasource.zip ddg_mock_datasource.py

echo "Done with zippin' and all..."
