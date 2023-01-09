
### Azure IAM permissions file
* https://github.com/iann0036/iam-dataset/commits/main/azure/provider-operations.json

### Azure IAM permission count analysis (single)
```
file="endjanprovider-operations.json"
a=$(jq -r '.[].operations[] | .name' < $file | wc -l)
b=$(jq -r '.[].resourceTypes[].operations[] | .name'  < $file | wc -l)
sum=$(($a + $b))
echo $sum
```

### Azure IAM permission count analysis (multiple)
```
for file in *.json; do
echo $file
a=$(jq -r '.[].operations[] | .name' < $file | wc -l)
b=$(jq -r '.[].resourceTypes[].operations[] | .name'  < $file | wc -l)
sum=$(($a + $b))
echo $sum
done
```

### Azure IAM permissions file
* https://github.com/iann0036/iam-dataset/commits/main/azure/built-in-roles.json

### Built-in role count analysis (single)
```
file="dec31-2021-built-in-roles.json"
echo $file
a=$(jq -r '.roles[].name' < $file | wc -l)
echo $a
```

### Built-in role count analysis (multiple)
```
for file in *.json; do
echo $file
a=$(jq -r '.roles[].name' < $file | wc -l)
echo $a
done
```
