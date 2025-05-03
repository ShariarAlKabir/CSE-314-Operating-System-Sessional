#!/bin/bash

# Check for correct number of arguments
if [ $# -ne 4 ]; then
    echo "Usage: $0 <zip_directory> <targets_directory>"
    exit 1
fi

zip_dir="$1"
targets_dir="$2"

# Get absolute path of test inputs directory (assumed next to script)
script_dir="$(cd "$(dirname "$0")" && pwd)"
tests_dir="$script_dir/$3"
answers_dir="$script_dir/$4"

# Function to recursively visit and unzip zip files
visit() {
    if [ -d "$1" ]; then 
        for i in "$1"/*; do 
            [ -e "$i" ] || continue
            visit "$i"
        done
    elif [ -f "$1" ]; then    
        if file "$1" | grep -qi 'zip archive'; then
            filename=$(basename "$1")
            name="${filename%.zip}"
            dest="unzip/$name"
            mkdir -p "$dest"
            unzip -q "$1" -d "$dest"
        fi
    fi
}

# Prepare workspace
mkdir -p "$targets_dir"/{C,C++,Java,Python}
echo "student_id,student_name,language,matched,not_matched,line_count,comment_count,function_count" > "$targets_dir"/result.csv
mkdir -p unzip

# Start processing input zip directory
visit "$zip_dir"

# Go into unzip directory
cd unzip || exit 1

# Rename folders and extract student info
for dir in */; do
    orig_name="${dir%/}"
    full_name="${orig_name%%_*}"
    student_id="${orig_name: -7}"
    new_name="$student_id"

    if [[ "$orig_name" != "$new_name" ]]; then
        mv "$orig_name" "$new_name"
    fi

    echo "$student_id,$full_name,UNKNOWN,0,0,0,0,0" >> "../$targets_dir/result.csv"
done

# Flatten subdirectories and clean up
for dir in */; do
    find "$dir" -mindepth 2 -type f -exec mv -t "$dir" --backup=numbered {} +
    find "$dir" -mindepth 1 -type d -empty -delete
done

cd ..

# Detect language and move folders
for dir in unzip/*/; do
    lang="UNKNOWN"
    line_count=0
    comment_count=0

    if find "$dir" -type f -iname "*.c" | grep -q .; then
        line_count=$(find "$dir" -type f -iname "*.c" -exec cat {} + | wc -l)
        comment_count=$(find "$dir" -type f -iname "*.c" -exec grep -c "//" {} + | awk '{s+=$1} END {print s}')
        mv "$dir" "$targets_dir"/C/
        lang="C"
    elif find "$dir" -type f -iname "*.cpp" | grep -q .; then
        line_count=$(find "$dir" -type f -iname "*.cpp" -exec cat {} + | wc -l)
        comment_count=$(find "$dir" -type f -iname "*.cpp" -exec grep -c "//" {} + | awk '{s+=$1} END {print s}')
        mv "$dir" "$targets_dir"/C++/
        lang="C++"
    elif find "$dir" -type f -iname "*.py" | grep -q .; then
        line_count=$(find "$dir" -type f -iname "*.py" -exec cat {} + | wc -l)
        comment_count=$(find "$dir" -type f -iname "*.py" -exec grep -c "#" {} + | awk '{s+=$1} END {print s}')
        mv "$dir" "$targets_dir"/Python/
        lang="Python"
    elif find "$dir" -type f -iname "*.java" | grep -q .; then
        line_count=$(find "$dir" -type f -iname "*.java" -exec cat {} + | wc -l)
        comment_count=$(find "$dir" -type f -iname "*.java" -exec grep -c "//" {} + | awk '{s+=$1} END {print s}')
        mv "$dir" "$targets_dir"/Java/
        lang="Java"
    fi

    student_id=$(basename "$dir")
    awk -v sid="$student_id" -v lang="$lang" -v lines="$line_count" -v comments="$comment_count" -F, 'BEGIN {OFS=","} {if ($1 == sid) {$3 = lang; $6 = lines; $7 = comments} } 1' "$targets_dir"/result.csv > tmp.csv && mv tmp.csv "$targets_dir"/result.csv
done

# Cleanup unzip
rm -rf unzip

########################################
# EXECUTION SECTION FOR ALL LANGUAGES #
########################################

# C++
for student_dir in "$targets_dir"/C++/*/; do
    find "$student_dir" -type f -iname "*.cpp" | while read -r cpp_file; do
        # Rename .cpp files to main.cpp
        dir_of_cpp=$(dirname "$cpp_file")
        mv "$cpp_file" "$dir_of_cpp/main.cpp"

        exe_file="${dir_of_cpp}/main.out"

        g++ "$dir_of_cpp/main.cpp" -o "$exe_file" 2>/dev/null
        if [ $? -ne 0 ]; then
            echo "Compilation failed: $dir_of_cpp/main.cpp"
            continue
        fi

        for i in {1..5}; do
            input_file="$tests_dir/test$i.txt"
            output_file="$dir_of_cpp/out$i.txt"
            if [ -f "$input_file" ]; then
                "$exe_file" < "$input_file" > "$output_file"
            else
                echo "Missing input file: $input_file"
            fi
        done

        # rm -f "$exe_file"
    done
done

# C
for student_dir in "$targets_dir"/C/*/; do
    find "$student_dir" -type f -iname "*.c" | while read -r c_file; do
        # Rename .c files to main.c
        dir_of_c=$(dirname "$c_file")
        mv "$c_file" "$dir_of_c/main.c"

        exe_file="${dir_of_c}/main.out"

        gcc "$dir_of_c/main.c" -o "$exe_file" 2>/dev/null
        if [ $? -ne 0 ]; then
            echo "Compilation failed: $dir_of_c/main.c"
            continue
        fi

        for i in {1..5}; do
            input_file="$tests_dir/test$i.txt"
            output_file="$dir_of_c/out$i.txt"
            if [ -f "$input_file" ]; then
                "$exe_file" < "$input_file" > "$output_file"
            else
                echo "Missing input file: $input_file"
            fi
        done

        # rm -f "$exe_file"
    done
done

# Java
for student_dir in "$targets_dir"/Java/*/; do
    find "$student_dir" -type f -iname "*.java" | while read -r java_file; do
        # Rename .java files to Main.java
        dir_of_java=$(dirname "$java_file")
        mv "$java_file" "$dir_of_java/Main.java"

        # Now compile the renamed Main.java
        javac "$dir_of_java/Main.java" 2>/dev/null
        if [ $? -ne 0 ]; then
            echo "Compilation failed: $dir_of_java/Main.java"
            continue
        fi

        for i in {1..5}; do
            input_file="$tests_dir/test$i.txt"
            output_file="$dir_of_java/out$i.txt"
            if [ -f "$input_file" ]; then
                (cd "$dir_of_java" && java Main < "$input_file" > "out$i.txt")
            else
                echo "Missing input file: $input_file"
            fi
        done

        # rm -f "$dir_of_java"/*.class
    done
done

# Python
for student_dir in "$targets_dir"/Python/*/; do
    find "$student_dir" -type f -iname "*.py" | while read -r py_file; do
        # Rename .py files to main.py
        dir_of_py=$(dirname "$py_file")
        mv "$py_file" "$dir_of_py/main.py"

        for i in {1..5}; do
            input_file="$tests_dir/test$i.txt"
            output_file="$dir_of_py/out$i.txt"
            if [ -f "$input_file" ]; then
                python3 "$dir_of_py/main.py" < "$input_file" > "$output_file"
            else
                echo "Missing input file: $input_file"
            fi
        done
    done
done

# Compare outputs with answers and update result.csv
for lang in C C++ Java Python; do
    for student_dir in "$targets_dir/$lang"/*/; do
        student_id=$(basename "$student_dir")

        matched=0
        not_matched=0

        for i in {1..5}; do
            student_out="$student_dir/out$i.txt"
            answer_file="$answers_dir/ans$i.txt"

            if [ -f "$student_out" ] && [ -f "$answer_file" ]; then
                if diff -q "$student_out" "$answer_file" > /dev/null; then
                    ((matched++))
                else
                    ((not_matched++))
                fi
            fi
        done

        # Update result.csv
        awk -v sid="$student_id" -v m="$matched" -v nm="$not_matched" -F, 'BEGIN {OFS=","} {if ($1 == sid) {$4 = m; $5 = nm} } 1' "$targets_dir/result.csv" > tmp.csv && mv tmp.csv "$targets_dir/result.csv"
    done
done

