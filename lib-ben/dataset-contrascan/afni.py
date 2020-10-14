"""
Class to run AFNI programs and write and store info about them.

Created 10/13/2020 by Benjamin Velie.
veliebm@gmail.com

"""

from datetime import datetime
import subprocess
from pathlib import Path
import json


class AFNI():
    """
    Class to run AFNI programs and store information about them.

    """

    def __init__(self, where_to_create_working_directory, program: str, args: list):

        self.start_time = datetime.now()

        # Store parameters.
        self.where_to_create_working_directory = Path(where_to_create_working_directory).absolute()
        self.program = program
        self.args = args

        # Make working_directory if it doesn't exist.
        self.working_directory = self.where_to_create_working_directory/self.program
        self.working_directory.mkdir(parents=True, exist_ok=True)

        # Execute AFNI program.
        self.runtime = subprocess.run(
            [self.program] + self.args,
            cwd=self.working_directory
        )

        # Record end time. Write logs.
        self.end_time = datetime.now()
        self.write_logs()


    def __repr__(self):
        """
        Defines how the class represents itself internally as a string.

        To learn more, consider reading https://docs.python.org/3/reference/datamodel.html#basic-customization

        """

        return f"{self.__class__.__name__}(working_directory='{self.working_directory}', program='{self.program}', args={self.args})"

    
    def write_logs(self):
        """
        Write program info to working directory.

        """

        # Store program info into a dict.
        program_info = {
            "Program name": self.program,
            "Working directory": str(self.working_directory),
            "Time to run program": str(self.end_time - self.start_time),
            "Complete command executed": self.runtime.args,
        }

        # Write the program info dict to a json file.
        output_json_path = self.working_directory / f"program_info.json"
        print(f"Writing {output_json_path}")
        with open(output_json_path, "w") as json_file:
            json.dump(program_info, json_file, indent="\t")