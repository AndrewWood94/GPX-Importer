"""
Loads config file into dictionary for script access.
"""
import yaml
from pathlib import Path


def create_folder(path):
    """Method to create path. Will also create parent folders if don't exist.

    Args:
        path (pathlib.Path): path to folder to create
    """
    try:
        path.mkdir(parents=True, exist_ok=False)
    except FileExistsError:
        print(f"{path} exists")
    else:
        print(f"{path} exists")


class Config():
    """Class to import config file and create results folder for experiment.
    """
    def __init__(self, config_path):
        """Initialise config class with config file specfied on config_path.

        Args:
            config_path (str): path to config file in .yaml format
        """
        config_path = Path(config_path)
        self.config_name = config_path.name
        self.config_dir_path = config_path.parents[0]

        self.load_config()

    def load_config(self):
        """Method to load config dictionary from given config yml"""
        with open(self.config_dir_path / self.config_name, 'r') as stream:
            try:
                self.config_dict = yaml.safe_load(stream)
            except yaml.YAMLError as exc:
                print(exc)

    def print_config(self):
        """Print config attributes
        """
        print(vars(self))

    def __getitem__(self, key):
        """Access config dict from Config directly.
        e.g. if config = Config('pth2configfile')
        Then can use config[key] rather than config.config_dict[key]
        Args:
            key (str): key in dict

        Returns:
            value: value associated to above key
        """
        return self.config_dict[key]


